---
layout: post
title:  "Automatically deploy GitHub branches to a subdomain"
date:   2015-09-25 14:30:29
categories: [github, bash, webhooks]
---

Even if you're the sole developer on a project, big or small, I always advocate using [git][git] for version control. Using version control software removes the tediousness of having to FTP individual files up to your production server, allows you to view the entire history of your repository, and encourage the use of ["feature branches"][branches] that can be merged into the "master branch" once ready.

With git work-flows, I usually recommend a 3-tier deployment environment:

1. Local
2. Testing 
3. Production

The *local* environment is where you should be doing all of your coding and debugging. You'll most likely have server software executing your code and allowing you to see the results at some flavor of `http://localhost`.

Your *testing* environment should closely mirror the setup of your *production* environment. It should have a publicly accessible URL and exists to determine how your code executes in a "live" environment without affecting your *production* data.

## Testing vs. Production
Let's say your production code is served from `http://example.com`. You might choose to serve your *testing* code from `http://test-example.com` or `http://example.net`.

Your 3-tier process most likely involves committing your local code, SSH-ing into your *testing* server, running `git pull`, switching to whatever feature branch you are testing, and finally merging into the master branch.

What if instead of this tedious process, we had every branch get automatically pulled into `[branch-name].example.com` upon creation? What's more, what if every local commit automatically updated the *testing* environment? That's exactly what we're going to automate.

## Git Hooks and Webhooks
I've [previously covered][previous article] how to use git hooks to automatically build and deploy a Jekyll site. These hooks can run scripts at many different points in the git work-flow to help better facilitate certain build/deploy processes. Although these hooks are native to the git platform, GitHub also offers its own version of hooks that it calls Webhooks.

Once set up, a GitHub Webhook can ping a URL you provide after most any type of [GitHub event][events] has occurred. It's up to you and your scripting skills to decide what happens after your URL is pinged.

In this tutorial's case, we're going to listen for three GitHub events: branch creation, branch pushing, and branch deletion. The pinged URL will then execute one of three shell scripts based on the GitHub event that occurred.

## Assumptions
This tutorial is based on the assumption that you have full control over the server in which your *testing* environment resides. The examples below are based on a server running the following:

- Apache 2.2.16 (Debian)
- Git 1.7.2.5

## Directory and File structure
It should only take a handful of files to get the functionality we want. I'm placing the files in the `/root/webhooks` directory on my server, but these can go just about anywhere. Make sure to remember the location though, it'll come back up in a bit.

{% highlight bash tabsize=2 %}
.
|── root
|	└── webhooks
|		├── branch-create.sh
|		├── branch-push.sh
|		├── branch-delete.sh
|		└── vhost.template
{% endhighlight %}

## The scripts: branch creation
The first script we'll be writing gets triggered when a new branch is created. The script will need to do the following:

1. Require a branch name to be supplied
2. Clone the repo into a directory with the same name as the branch
3. [Check out][git checkout] the supplied branch
4. Write a [Virtual Host][virtual host] for the branch that points the proper subdomain to its directory
5. Restart Apache

<div class="highlight-header">/root/webhooks/branch-create.sh</div>
{% highlight bash %}
#!/bin/bash

cd /var/www/html
git clone git@github.com:user/repo.git $1 	# your repo here
cd $1

git fetch origin
git checkout -b $1 origin/$1

sed 's/{SITE}/$1/g' vhost.template > /etc/apache2/sites-available/$1.conf

a2ensite $1.conf

apachectl restart
{% endhighlight %}

Even if you've never written a bash script, you should be able to follow along fairly easily. 

First, the repo is cloned into the web server directoy `/var/www/html`. After the repo is successfully cloned, the supplied branch is checked out.

The `$1` variable is a shell script argument. When the script is run from the command line you pass in argument(s) immediately following the script name: `./branch-create.sh branch-name`. In this example `branch-name` gets assigned to `$1`.

Next, we use the `sed` [utility][sed] to look for the string `{SITE}` in our `vhost.template` file. The string is replaced with the supplied branch name and the file is written to Apache's VirtualHost directory.

<div class="highlight-header">/root/webhooks/vhost.template</div>
{% highlight apache tabsize=3 %}
<VirtualHost *:80>
	DocumentRoot "/var/www/html/{SITE}/"
	ServerName {SITE}.example.com
</VirtualHost>
{% endhighlight %}

Finally, we run the `a2ensite` [command][a2ensite] to enable our new VirtualHost, and `apachectl restart` to restart Apache.

It's important to note that Apache must be restarted for our VirtualHost changes to take effect.

## The scripts: branch push
The next script will push (update) an existing feature branch. Because our `branch-create.sh` script cloned the repo into `/var/www/html/[branch-name]`, all this script needs to do is navigate to that directory and run `git pull`.

<div class="highlight-header">/root/webhooks/branch-push.sh</div>
{% highlight bash %}
#!/bin/bash

cd /var/www/html/$1
git pull
{% endhighlight %}

There's no need to restart Apache because we're not modifying any VirtualHosts.

## The scripts: branch deletion
The branch deletion script should remove all traces of our cloned repo and its associated VirtualHost.

<div class="highlight-header">/root/webhooks/branch-delete.sh</div>
{% highlight bash %}
#!/bin/bash

rm -rf /var/www/html/$1
rm /etc/apache2/sites-available/$1.conf

apachectl restart
{% endhighlight %}

Always proceed with caution when using the `-rf` flag, as it will recursively and forcibly remove every file in the supplied path.

## Setting up the webhook
At this point in the tutorial we've automated many of the branch management processes. We could `ssh` into our server and run `./branch-create.sh branch-name` from our `webhooks` directory and our script would run its task. Let's take it one step further and eliminate the need to `ssh` by creating a webhook.

Navigate to your GitHub repo's settings page. There you will see an option to add a webhook. 

![Add a Webhook]({{ site.s3 }}/images/2015/09/add-webhook.png){:class="th"}

There's a few options we're going to change on this page. The **Payload URL** is the endpoint that GitHub will ping when a specified event has occurred. For simplicity, let's say the endpoint is `http://example.com/webhook.php` and resides at `/var/www/html/webhook.php`.

We're going with PHP for our endpoint, but this could be any server-side language, as long as it can consume `POST` requests.

Next, we'll want to set the **Content type** to `application/x-www-form-urlencoded`. This will make it a bit easier for our PHP script to parse.

For our purposes, we can leave the **Secret** field empty. However, if you decide to implement this tutorial into your deployment process, you will want to [read up][validate payload] on how this field can help prevent unauthorized and malicious requests.

![Webhook Events]({{ site.s3 }}/images/2015/09/webhook-events.png){:class="th"}

There are dozens of events that can trigger a GitHub webhook, but we only care about *Create*, *Push*, and *Delete*. Make sure at least those three options are selected.

Once you save the page, GitHub is all set to ping your server when those selected events occur to your repository. Let's make sure there's something to ping!

## The payload destination
Above, we set the **Payload URL** to `http://example.com/webhook.php`. This will be the script that acts upon the payload that GitHub sends it.

<div class="highlight-header">/var/www/html/webhook.php</div>
{% highlight php startinline tabsize=3 %}
$script_path = "/root/webhooks";
$blacklist = array("www", "api");

$payload = json_decode($_POST['payload']);
$headers = apache_request_headers();

$event = $headers['X-github-event'];	// create, push, or delete
$branch = end(explode("/", $payload['ref']));

if ((strlen($branch) > 0) && !in_array($branch, $blacklist)) {
	$cmd = "sudo {$script_path}/branch-{$event}.sh {$branch}";
	echo shell_exec($cmd);
}
{% endhighlight %}

The payload will contain a plethora of information, but we're just looking for a few key pieces. Namely, the event type that was triggered and the branch in which it occurred. 

The event type is sent as a request header named `X-github-event`.

The branch name is a bit trickier to determine. We'll be looking in the `ref` parameter of the payload. Depending on the event type, GitHub may send the short branch name (e.g. `master`), or the full branch name (e.g. `refs/heads/master`).

We'll also want to prevent certain branch names from being deployed. Depending on how your server is set up, a feature branch named `www` might deploy to `www.example.com`. For this reason we implement a blacklist.

The above script will take all this into account and execute the proper shell script using PHP's `shell_exec` method. We'll  make sure to `echo` the result so GitHub can record our server's response, in case there's ever a delivery failure. 

## Sudo permissions
Open your shell and run the command `whoami`. It should return the name of whichever user is logged into the shell session. When you execute a shell command from a server script, it will run it as the user `www-data`. This is a sandboxed user with very limited permissions, should your web application be compromised.

As it is, the `www-data` user will most likely not have permission to run the shell scripts we've written. We're going to want to add `www-data` to our list of [sudoers][sudoers] and grant it access to the `/root/webhooks` directory only.

This can be accomplished using the `visudo` tool.

<div class="highlight-header">visudo</div>
{% highlight bash %}
...
# User privilege specification
root            ALL=(ALL) ALL
www-data        ALL=NOPASSWD: /root/webhooks/
...
{% endhighlight %}

Once you run the `visudo` command, you'll want to add the line that pertains to `www-data` in the *User privilege specification* section and save out the file.

## Conclusion and thoughts
At this point you should be fully automated! Any branch you create locally and publish, delete, or push to GitHub should automatically trigger the appropriate script on your *testing* server. You'll also have a dedicated subdomain for the branch to live on.

Again, if you decide to use this method for anything beyond personal projects, I highly recommend [securing][validate payload] your webhooks. As is, a properly spoofed request to your payload URL could allow arbitrary code to be run on your server. That's obviously not a good thing. Play it safe!


[git]: https://git-scm.com/
[branches]: https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging
[events]: https://developer.github.com/webhooks/#events
[previous article]: /how-to-jekyll
[apache]: https://en.wikipedia.org/wiki/Apache_HTTP_Server
[mustache bash]: https://github.com/tests-always-included/mo
[git checkout]: http://git-scm.com/docs/git-checkout
[virtual host]: https://en.wikipedia.org/wiki/Virtual_hosting
[sed]: https://en.wikipedia.org/wiki/Sed#Usage
[a2ensite]: http://man.he.net/man8/a2ensite
[validate payload]: https://developer.github.com/webhooks/securing/#validating-payloads-from-github
[payload]: https://developer.github.com/webhooks/#payloads
[sudoers]: https://help.ubuntu.com/community/Sudoers
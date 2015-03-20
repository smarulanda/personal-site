---
layout: post
title:  "How I got this site running with Jekyll and auto-deploying with Git"
date:   2015-02-07 14:22:27
categories: [jekyll, git, digitalocean, apache, bash]
---
I really like [Jekyll][jekyll]. Well, that's mostly true. More so, I really like what Jekyll isn't. It's not an over-bloated CMS. It doesn't have a WYSIWYG editor. It doesn't have a file-uploader. It doesn't require a database. Basically, it's not Wordpress.

I'd heard enough guests on the [ShopTalk][shoptalk] podcast recommend Jekyll so I decided to give it a look. It's great. It ships with built-in [Sass][sass] support. I can write my blog posts and pages in Markdown or HTML (or any custom parser). And with a git hook I can deploy my changes with a simple commit.

**Note:** [GitHub Pages][github pages] supports [Jekyll][github pages jekyll] and will actually run your project through the program on every push. This is great if you don't want to provide your own hosting, however, these pages will be generated using the `--safe` option. This means you can't use certain fun Jekyll features like [plugins][jekyll plugins].

So let's go through all the steps I took to get this site running and automatically deploying.

## My setup
The steps we'll go through in this post will mostly pertain to my local and production setups, but they should be reproducible on most any machine.

Local: 

- OS X 10.10.2
- Ruby 2.0.0
- Git 1.9.3

Production:

- Ubuntu 14.04 on [DigitalOcean][digitalocean]
- Apache 2.4
- Ruby 1.9.3
- Git 2.3.0

## Installing Jekyll
Make sure you have Ruby installed. If you don't, check out [this guide][install ruby]. You'll also need [RubyGems][rubygems].

Once you're set you'll want to run `gem install jekyll` on both your local and production machines. This will install the Jekyll gem.

If you want to test out your Jekyll installation, simply navigate to a usable directory on your local machine and run:

{% highlight bash %}
$ jekyll new personal-site
$ cd personal-site
$ jekyll serve
# => Now browse to http://localhost:4000
{% endhighlight %}

Jekyll will have created a directory called `personal-site` and filled it with enough goodies to get your project started! It's even running its own local server that can watch for file changes in your project's directory. 

Playing around with the generated files should give you a good handle on how Jekyll operates. For everything else there's the wonderful [documentation][jekyll doc].

## Set up the public directory
This step can vary greatly depending on what kind of production machine you're using. First, find your default server directory. In Apache for Ubuntu it's the `/var/www` directory. If you have multiple domains pointing to the same production machine you can map your site to a different directory using VirtualHosts.

I have a few domains pointed to the same machine, so I'm going to create a new directory in `var/www` for my personal site.

{% highlight bash %}
$ cd /var/www
$ mkdir personal-site
{% endhighlight %}

Let's create an Apache VirtualHost and point it to this new directory. We'll navigate to `/etc/apache2/sites-available`, open an editor (like nano or vi) for a new file `personal-site.conf`, and copy the following:

{% highlight bash %}
<VirtualHost *:80>
	ServerName sebastianmarulanda.com
	DocumentRoot /var/www/personal-site
</VirtualHost>
{% endhighlight %}

Next, we'll enable the site with `a2ensite personal-site.conf` and restart Apache with `/etc/init.d/apache2 restart`. Still with me?

## Setting up Git
[Install git][install git] if you haven't already!

We're going to be hosting the project's git repository on our production machine. In that repo we will create a post-receive hook that will clone the project into a temporary directory, run the Jekyll build task, and output the built site to the public directory. Sounds easy enough, right?

First, let's create a new user on our production machine. This user will only run git-specific tasks.

{% highlight bash %}
$ useradd -m git	# create user git and their home directory
$ passwd git		# set user git's password
{% endhighlight %}

Let's switch to our newly created user `su git` and their home directory `cd ~`. We're going to create a directory here for our repository (and any future repositories) and initialize an empty repo.

{% highlight bash %}
# On the production machine
$ mkdir repos && cd repos
$ mkdir personal-site.git && cd personal-site.git
$ git init --bare
{% endhighlight %}

All right, we've created the empty repo on our production machine. Let's clone this empty repo onto our local machine and copy all of our Jekyll stuff into it.

{% highlight bash %}
# In a local directory
$ git clone git@yoursite.com:repos/personal-site.git	# clone over ssh
$ cp /path/to/personal-site/* personal-site.git/	# copy jekyll contents
{% endhighlight %}

All these changes are itching to be committed to our remote repository. Let's go ahead and do that with `git commit -m "Initial commit"`. 

If you don't want to keep using the command line after this initial setup, there are plenty of great Git GUI interfaces out there. I've been using the [GitHub app][github for mac] for Mac to commit and sync my changes (it allows non-GitHub remotes).

## Adding a hook
Alright. We've gotten our git workflow set up, but our site still needs to be made accessible on our production server. This is where [git hooks][git hooks] come into play.

Git hooks allow us to run server scripts during most any point of the git workflow. Let's write a script to run after a push to our production server. We want this script to clone our repository into a temporary directory and then using Jekyll, build the site into our `/var/www/personal-site` directory. Luckily, we can do all this with just a few lines of code!

On our production server as the `git` user let's `cd ~/repos/personal-site.git/hooks` to change into our hooks directory that was generated when we first initialized our empty repo. You will see some sample hooks here, but we want to create a new one named `post-receive` with the following code.

{% highlight bash %}
#!/bin/bash

GIT_REPO=$HOME/repos/personal-site.git
TMP_GIT_CLONE=$HOME/tmp/git/personal-site.git
DESTINATION=/var/www/personal-site

git clone $GIT_REPO $TMP_GIT_CLONE
jekyll build --source $TMP_GIT_CLONE --destination $DESTINATION

rm -rf $TMP_GIT_CLONE

exit
{% endhighlight %}

Even if you've never written a bash script before, this should be fairly easy to follow along with. 

The first three variables are defining the location of the git repo, the temporary clone location, and the final destination for our built site.

Next, the git repo is cloned into the temporary location. Once cloned the script will run the Jekyll build task and specifiy a destination (the public directory). Finally, the temporary clone is removed. Yay!

## All together now
We should now have everything we need to successfully auto-deploy our local changes to our production server. Using your favorite git GUI (or the command line) you can commit and push your changes to the repo on your production server. Once the repo receives your changes it will fire off the `post-receive` hook which will build your site. That's it!

## Useful Links
- [Git on the Server - Setting Up the Server][git on the server]{:target="_blank"} - git-scm
- [Setting up Push-to-Deploy with git][push to deploy]{:target="_blank"} - Kris Jordan

[jekyll]: http://jekyllrb.com
[shoptalk]: http://shoptalkshow.com
[sass]: http://sass-lang.com/
[github pages]: https://help.github.com/articles/what-are-github-pages/
[github pages jekyll]: https://help.github.com/articles/using-jekyll-with-pages/
[jekyll plugins]: http://jekyllrb.com/docs/plugins/
[jekyll doc]: http://jekyllrb.com/docs/home/
[digitalocean]: http://digitalocean.com
[install ruby]: https://www.ruby-lang.org/en/documentation/installation/
[rubygems]: https://rubygems.org/pages/download
[install git]: http://git-scm.com/book/en/v2/Getting-Started-Installing-Git
[github for mac]: https://mac.github.com/
[git hooks]: http://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks
[git on the server]: http://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server
[push to deploy]: http://krisjordan.com/essays/setting-up-push-to-deploy-with-git
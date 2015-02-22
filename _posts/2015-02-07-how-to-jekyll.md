---
layout: post
title:  "How I got this site up and running with Jekyll"
date:   2015-02-07 14:22:27
categories: jekyll
---
I really like Jekyll. 
It's important to add the `_drafts` and `_site` directories to your `.gitignore` file.
I pull the repo into my DigitalOcean droplet. Next, I set up a virtualhost in Apache to point my domain to the site.

<blockquote class="twitter-tweet" lang="en"><p>I nominate Git 2.3&#39;s push-to-deploy feature for the prestigious &quot;Coolest But Most Likely To Be Abused&quot; Award of 2015 <a href="https://t.co/FOklR1O3S7">https://t.co/FOklR1O3S7</a></p>&mdash; Adrian Petrescu (@apetresc) <a href="https://twitter.com/apetresc/status/565185637247373312">February 10, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

Add a virtualhost.

How I set up my GitHub webhook.
`git pull && jekyll build`

{% highlight php %}
<?php
$secret = "SECRET GOES HERE";

$headers = apache_request_headers();
$signature = $headers["X-Hub-Signature"];

// Split signature into algorithm and hash
list($algo, $hash) = explode("=", $signature, 2);

// Get payload
$payload = file_get_contents("php://input");

// Calculate hash based on payload and the secret
$payloadHash = hash_hmac($algo, $payload, $secret);

// Check if hashes are equivalent
if ($hash !== $payloadHash) {
	// Kill the script or do something else here.
	die("Bad secret");
}

// Your code here.
echo shell_exec("cd .. && git pull && jekyll build");
?>
{% endhighlight %}

Check out the site repo on [GitHub][repo]{:target="_blank"} to see how this site was built.
Setting up the [server][git on the server]{:target="_blank"}.

## Useful Links
- [Git on the Server - Setting Up the Server][git on the server]{:target="_blank"} - git-scm
- [Trying out the "Push to deploy" feature of Git 2.3][push to deploy]{:target="_blank"} - Cedric Meury

[repo]: http://github.com/smarulanda
[git on the server]: http://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server
[push to deploy]: http://www.cedric-meury.ch/2015/02/trying-out-the-push-to-deploy-feature-of-git-2-3/
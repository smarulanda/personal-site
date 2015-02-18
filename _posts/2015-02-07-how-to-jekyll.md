---
layout: post
title:  "How to get a site up and running with Jekyll"
date:   2015-02-07 14:22:27
categories: jekyll
---
It's important to add the `_drafts` and `_site` directories to your `.gitignore` file.
I pull the repo into my DigitalOcean droplet. Next, I set up a virtualhost in Apache to point my domain to the site.

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

Check out the site repo on [GitHub][repo] to see how this site was built.

[repo]: http://github.com/smarulanda
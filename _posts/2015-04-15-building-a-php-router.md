---
layout: post
title: "Building a lightweight PHP router"
date: 2015-04-15 14:22:27
categories: [php, apache]
---

Non-semantic URLs are out. There's no reason for your users to see a long chain of query strings in their address bar. They are not memorable, they give the user very little feedback, and they may even expose your server-side setup. With just a little bit of back-end wizardry we can turn something like this:

`http://example.com/index.php?mod=products&cat=193&item=52`

into this:

`http://example.com/products/193/52`

or even:

`http://example.com/products/coffee/french-press`

These clean URLs are known as [Semantic URLs][semantic url] or [RESTful URLs][semantic url]. We're going to accomplish this by creating a small and reusable PHP class and an Apache `.htaccess` file.

## The .htaccess file

An `.htaccess` file lives in the directory level of your application. They allows us to override the server's global configuration for the particular directory. There are many use cases for including an `.htaccess` file, the most common being authorization/authentication for the directory. We can also use it to blacklist certain IP addresses, set custom error responses, and what we'll be focusing on in this project: rewriting URLs.

Let's take a look at this `.htaccess` file. These 3 lines are all we'll need for this project.

{% highlight apache tabsize=3 %}
RewriteEngine on
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule . index.php [L]
{% endhighlight %}



[semantic url]: http://en.wikipedia.org/wiki/Semantic_URL
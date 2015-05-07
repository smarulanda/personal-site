---
layout: post
title: "Building a lightweight PHP router"
date: 2015-04-15 14:22:27
categories: [php, apache]
---

Non-semantic URLs are out. There's no reason for your users to see a long chain of query strings in their address bar. They are not memorable, they give the user very little feedback, and they may even expose your server-side setup. With just a little bit of back-end wizardry we can turn something like this:

`http://example.com/index.php?mod=profiles&id=193&page=3`

into this:

`http://example.com/profile/193/page/3`

These clean URLs are known as [Semantic URLs][semantic url] or [RESTful URLs][semantic url]. We're going to accomplish this by creating a reusable PHP class and an Apache `.htaccess` file.

[semantic url]: http://en.wikipedia.org/wiki/Semantic_URL
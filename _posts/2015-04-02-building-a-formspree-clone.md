---
layout: post
title:  "Building a Formspree clone with Django and Mandrill"
date:   2015-04-02 14:22:27
categories: [django, mandrill, digitalocean]
---

It can be difficult dealing with contact forms if you have little control over the server that your site lives on. HTML `mailto:` forms are notoriously unreliable and hinge on the assumption that the user has a default email client set up. Instead of worrying about mail clients, server setups, or mailto links. This is where services like [Formspree][formspree] shine.

Check out the source of my [contact][contact] page. The form POSTs to `//formspree.io/sebastian@marulanda.us`.

http://tutorial.djangogirls.org/

[contact]: /contact
[formspree]: http://formspree.io/
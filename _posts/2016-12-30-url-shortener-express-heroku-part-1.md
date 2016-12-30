---
layout: post
title: "Let's build a URL shortener with Express (and deploy to Heroku) - Part 1"
date: 2016-12-30 14:22:27
categories: [node.js, express, postresql, heroku]
project_link: https://github.com/smarulanda/url-shortener
---
Although I'm most comfortable developing in PHP, I've found myself reaching for [node.js][node] quite often for small-ish scripting tasks. I've covered a couple of these projects in previous tutorials: [Amazon Price Tracker][price tracker] and [CLI Weatherman][weatherman]. These are all purely command line applications, though. Let's try building an entire web application.

While it is possible to write a full web server and application in [raw node][raw node], I always recommend using an established web framework. In this tutorial we'll be using [Express][express].

> **Note:** This tutorial assumes you've previously set up a node project using `npm`. If you need a refresher, check out one of my previous [posts][weatherman].

## What we're building
We're going to be writing a URL shortener. You've likely come across a [bit.ly][bitly], [goo.gl][googl], or [tinyurl][tinyurl] link around the web. These services take a fully qualified URL (which may be dozens of characters long) and produce a much shorter link that can be easily shared.

For example, the URL [`https://goo.gl/4ZRBqI`](https://goo.gl/4ZRBqI) will redirect you to the installation instructions for Express: [`http://expressjs.com/en/starter/installing.html`](http://expressjs.com/en/starter/installing.html).

This tutorial will break down how Express can be used to set up routes, communicate with a database, and render template views. We will also go over how to deploy this application to the web (for free!) on Heroku.

![URL Shortener]({{ site.s3 }}/images/2016/12/shortener.png){:class="th"}

<p class="text-center">
	<a href="{{ page.project_link }}" class="btn btn-dark" target="_blank"><i class="fa fa-github"></i> View the source on GitHub</a>
</p>

## Setting up the project
We'll start by creating a directory named `url-shortener`. Navigate into this directory from the command line and run `npm init` to set up a barebones node project (the suggested defaults should be fine).

The entry point for our application will be `index.js`, go ahead and create it. Your directory structure should look like this:

{% highlight bash tabsize=4 %}
url-shortener/
├── index.js
└── package.json
{% endhighlight %}

## A few dependencies
This node project relies on four dependencies that we'll explore more in-depth later:

1. [express][gh express]: the web framework
2. [ejs][gh ejs]: embedded javascript templating
3. [body-parser][gh bp]: node middleware that can parse incoming request bodies
4. [pg-promise][gh pgp]: a PostgreSQL database interface

Let's go ahead and get the installation of these dependencies out of the way:

{% highlight bash %}
$ npm install express ejs body-parser pg-promise --save
{% endhighlight %}

You'll notice that these packages have been added to a new directory: `node_modules`, and by using the `--save` flag they will also appear in the `package.json` file.

## Express and routes
Express helps us simplify some of the overhead that comes with creating a node web application. With just a few lines of code we can respond to different URL requests to our app. In our case we need to worry about three routes:

1. `GET /` - The index page of our app, a form to submit a long URL
2. `POST /shorten` - The page our form submits to, this will create a new short link
3. `GET /:key` - Any string of text/numbers, we will check if it is a short URL and redirect accordingly

Routes refer to how an application responds to a client request to a particular endpoint, which is a URI (or path) and a specific [HTTP request method][http methods] (GET, POST, and so on).

Let's start adding these routes to our `index.js` file:

<div class="highlight-header">~/url-shortener/index.js</div>
{% highlight js tabsize=4 %}
var express = require('express');
var app = express();

// The index page
app.get('/', function (req, res) {
	res.send('The index page');
});

// Post url and shorten
app.post('/shorten', function (req, res) {
	res.send('Submit here');
});

// Find long URL from short, and redirect
app.get('/:key', function (req, res) {
	res.send('Your key was: ' + req.key)
});

// Listen on port 3000
app.listen(3000, function () {
	console.log('Listening on port 3000');
});
{% endhighlight %}

The first line above imports `express` from our `node_modules` directory, while the second instantiates the Express `app`.

The next several blocks demonstrate how we define our routes in Express. The `app.get('/', ...)` block will get called when a user makes a `GET`request to our site's URL with nothing else in the path. On the other hand, if the user does add something to the URL path, only the third route block will match. The `:key` in our route is a wild card; it will match any path.

Give the code a try. Run the following command from the application directory:

{% highlight bash %}
$ node index.js
{% endhighlight %}

Next, open your browser and navigate to [`localhost:3000`](localhost:3000). This should match your index `/` path. Navigating to [`localhost:3000/qwerty`](localhost:3000/qwerty) should match the wild card path.

When your browser navigates to either of the above URLs, it is making a `GET` request. There are several ways to trigger a `POST` request, the most common is submitting a form, which we will cover in a bit.

## Express `req` and `res`
As we saw in the application code above, whenever a route was matched, the provided callback method `function (req, res) { ... });` was executed. The two parameters provided are the [`request`][req] and [`response`][res].

From the `req` object we can access properties supplied with the client's HTTP request. Properties like cookies, IP address, query strings, etc. We will eventually use `req.body` to extract a submitted long URL.

The `res` object sends an HTTP response back to the user who made a request. With it, we can send an HTTP code, a file, a cookie, etc. In our case, we will be using it to render some HTML templates, as well as redirecting the user to the long URL.

> **Note:** You can give these objects whatever name you'd like, `req` and `res` are merely the common convention.

## Views and view engines
Express allows us to use most any [view/templating engine][view engine] we want (we could even write our own). A templating engine will allow us to write HTML-like files that can also display dynamic content.

For this application we'll be using [EJS][ejs] (embedded javascript). These files will have a `.ejs` extension and reside in a new directory within our project: `views`. These `.ejs` files are mostly HTML, but we can also pass objects from our `index.js` to these templates and embed them within the markup.

We'll need to tell Express to set the view engine to EJS and to look for those files within the `views` directory:

<div class="highlight-header">~/url-shortener/index.js</div>
{% highlight js tabsize=4 %}
var express = require('express');
var app = express();

// Set view directory and engine
app.set('view engine', 'ejs');
app.set('views', __dirname + '/views');
...
{% endhighlight %}

## The index view
The most basic URL shortening service simply needs a form with a text input (for the long URL), and a submit button. If you're following along with the [github repository]({{ page.project_link }}) you'll notice that I've added a bit more than just a form. For the sake of brevity I won't go over these, but please feel free to tinker around with what I've added.

Create an `index.ejs` file in your `views` directory with the following content:

<div class="highlight-header">~/url-shortener/views/index.ejs</div>
{% highlight html tabsize=4 %}
<!DOCTYPE html>
<html lang="en">
<head>
	<title>URL Shortener</title>
</head>
<body>
	<form action="/shorten" method="POST">
		<input type="text" name="url" placeholder="Long URL">
		<button type="submit">Submit</button>
	</form>
</body>
{% endhighlight %}

Next, we want our index route to render this template. Back in `index.js`, change that callback method to this:

<div class="highlight-header">~/url-shortener/index.js</div>
{% highlight js tabsize=4 %}
...
app.get('/', function (req, res) {
    res.render('index');
});
...
{% endhighlight %}

> **Note:** Every time you make a change to the javascript, you'll want to restart the server with `$ node index.js`. 

## To be continued...
By this point you should have a locally-running Express application. The routes you've set should respond accordingly and can render EJS templates.

In the next tutorial we will cover setting up a PostgreSQL database, generating short codes, and deploying everything to Heroku.

Stay tuned!

## Useful links
- [Express Hello World example](https://expressjs.com/en/starter/hello-world.html){:target="_blank"} - expressjs.com
- [Node.js With Express And EJS](https://www.codementor.io/nodejs/tutorial/node-with-express-and-ejs){:target="_blank"} - codementor

[node]: http://nodejs.org
[price tracker]: /amazon-price-tracker-pushbullet
[weatherman]: /cli-weatherman-npm
[raw node]: https://nodejs.org/en/docs/guides/anatomy-of-an-http-transaction/
[express]: http://expressjs.com/
[bitly]: https://bitly.com/
[googl]: https://goo.gl
[tinyurl]: http://tinyurl.com/
[gh express]: https://github.com/expressjs/express
[gh ejs]: https://github.com/mde/ejs
[gh bp]: https://github.com/expressjs/body-parser
[gh pgp]: https://github.com/vitaly-t/pg-promise
[http methods]: https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods
[req]: http://expressjs.com/en/4x/api.html#req
[res]: http://expressjs.com/en/4x/api.html#res
[view engine]: https://expressjs.com/en/guide/using-template-engines.html
[ejs]: http://ejs.co/
[postgres]: https://www.postgresql.org/
[postgres install]: https://wiki.postgresql.org/wiki/Detailed_installation_guides
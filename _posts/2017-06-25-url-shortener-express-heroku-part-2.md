---
layout: post
title: "Let's build a URL shortener with Express (and deploy to Heroku) - Part 2"
date: 2017-06-25 22:50:27
categories: [node.js, express, postresql, heroku]
project_link: https://github.com/smarulanda/url-shortener
---

Welcome back! If you followed along in [Part 1][part 1] of this tutorial, you should have a locally running Express application with the appropriate routes set up for shortening URLs. These routes won't actually perform any logic just yet, but let's try and get our boilerplate off our local machine and up onto the web.

To do this we'll use the "platform as a service", [Heroku][heroku]. Using a PaaS can be a great option if you don't want to worry about maintaining your own application servers. We can simply deploy code to Heroku and they will spin up the appropriate environment for us.

> **Note:** This tutorial assumes you are familiar with the version control system, `git`, and have a basic understanding of relational databases and Structured Query Language (SQL).

## Preparing the app for Heroku

There are only a handful of differences that will prevent our code, as-is, from running on Heroku. We've specified that our app will run on port `3000`. However, this will likely not be the port that is opened for us.

The Heroku port number will be available to us as an [environment variable][node env]. In our code, we can check for the presence of a `PORT`. Barring the existance of one, we can assume we are in our local environment and use `3000` instead:

<div class="highlight-header">~/url-shortener/index.js</div>
{% highlight js tabsize=4 %}
var express = require('express');
var app = express();

// Check for a heroku port
app.set('port', (process.env.PORT || 3000));

...

// Listen on assigned port
app.listen(app.get('port'), function () {
	console.log('listening on port ' + app.get('port'));
});
{% endhighlight %}

Heroku also relies on an application being a `git` repository. We deploy our application by pushing our changes to a git repository on Heroku. Let's set up our local git repository:

{% highlight bash %}
$ git init
Initialized empty Git repository in ...
{% endhighlight %}

This will initialize an empty git repo, but before we make our first commit we'll need to create a `.gitignore` file.

A `gitignore` file contains a list of all the files we don't want git to track. In this project's case, that would be everything in the `node_modules` directory. Although all the files in there are necessary for our application to run, we don't need to track them, as they are already referenced in our `package.json` file. They will be installed by Heroku on deployment.

It's also a good idea to ignore any npm debug logs:

<div class="highlight-header">~/url-shortener/.gitignore</div>
{% highlight bash %}
node_modules
npm-debug.log
{% endhighlight %}

Once our app is deployed, Heroku will need to know what command to run in order to start it. We need to add a [Procfile][procfile], and specify what command will kick off the `web` process. It's the same command we use to start the application locally:

<div class="highlight-header">~/url-shortener/Procfile</div>
{% highlight text %}
web: node index.js
{% endhighlight %}

Finally, let's add and commit all of our files to the git repository:

{% highlight bash %}
$ git add -A && git commit -m "Initial commit"
{% endhighlight %}

## Deploying to Heroku

You'll want to make sure you have a [Heroku][heroku signup] account set up. Don't worry, all the services we'll use for this project are free! Heroku offers a great [command-line tool][heroku cli] to help us get up and running.

Once you've set up the CLI tool, navigate to your project's directory and log in to the Heroku service:

{% highlight bash %}
$ heroku login
{% endhighlight %}

Next, create a Heroku application:

{% highlight bash %}
$ heroku create
Creating app...
{% endhighlight %}

Heroku will generate a random name for the app and add a git remote (called heroku) to your local git repository. Code is deployed by pushing to the master branch of the heroku remote:

{% highlight bash %}
$ git push heroku master
{% endhighlight %}

The application should now be accessible on the web. Launch it with the following command:

{% highlight bash %}
$ heroku open
{% endhighlight %}

Now, whenever we want to deploy changes to our application, we `git commit` and `git push heroku master`.

## Setting up the database
When a user submits a URL to be shortened, the application will generate a short code for it. We need a place to store that reference. The type of database we choose to use for this scenario is not especially important; we only need one table's worth of storage. Heroku offers a simple way to provision a [PostgreSQL][postgres] database, so that's what we're going with.

You will also want to [install PostgreSQL][postgres install] locally. You don't need to create a local database to follow this project, but you will need the software to make changes to the Heroku database.

The following command will install the postgres addon to your Heroku dyno. It will also set a `DATABASE_URL` environment variable:

{% highlight bash %}
$ heroku addons:create heroku-postgresql:hobby-dev
Adding heroku-postgresql:hobby-dev...
{% endhighlight %}

Use the `heroku pg:psql` command to connect to the remote database. We need to create a table for our URL entries. Each row should contain a `url` (the original url) and a `key` (the shortened url key):

{% highlight bash %}
$ heroku pg:psql
psql (9.6.1)
Type "help" for help.

=> CREATE TABLE entry (key text, url text);
CREATE TABLE
{% endhighlight %}

If you want to continue working locally as well, you'll follow the same process as above, but leave out the `heroku pg:`.

Now that our database and table are set up, we need our code to read and insert records. We'll use the [`pg-promise`][pg-promise] library to do a lot of the heavy lifting.

While we're here, let's also install the [`random-key`][random-key] package (to generate a random key for each short URL), and the [`body-parser`][body-parser] package (to read POSTed form data).

{% highlight bash %}
$ npm install pg-promise random-key body-parser --save
{% endhighlight %}

And in our `index.js` file:

<div class="highlight-header">~/url-shortener/index.js</div>
{% highlight js tabsize=4 %}
var express = require('express');
var bodyParser = require('body-parser');
var random = require('random-key');
var pg = require('pg-promise')();

var app = express();
var db = pg(process.env.DATABASE_URL || 'postgres://psql:psql@localhost');

app.use(bodyParser.urlencoded({ extended: false }));
{% endhighlight %}

## The logic

The `/shorten` path of our application will be submitted to by the main page form. Thanks to the `body-parser` module, we'll be able to read the submitted URL from `req.body.url`.

We generate a 6-digit `key` to pair with the `url` and insert them into the database. We can then render a new view and pass it our shortened `link`.

<div class="highlight-header">~/url-shortener/index.js</div>
{% highlight js tabsize=4 %}
app.post('/shorten', function (req, res) {
	var url = req.body.url;
	var key = random.generate(6);

	// check that URL has been submitted
	if (typeof url === 'undefined') {
		res.redirect('/');
	}
	
	// insert the new record, render view with link
	db.none("insert into entry(key, url) values($1, $2)", [key, url])
	.then(function (data) {
		res.render('shorten', { link: req.headers.origin + "/" + key });
	});
});
{% endhighlight %}

Don't forget to create the new `.ejs` view. It will output the `link` variable that we created in the code above:

<div class="highlight-header">~/url-shortener/views/shorten.ejs</div>
{% highlight html tabsize=4 %}
<!DOCTYPE html>
<html lang="en">
<head>
    <title>URL Shortener</title>
</head>
<body>
	<form>
		<label>Shortened URL:</label>
		<input type="text" value="<%= link %>" readonly>
	</form>
</body>
{% endhighlight %}

Let's verify that our code can actually create these database entries and output them. If you want to test locally, run `$ node index.js` and navigate to [`localhost:3000`](localhost:3000).

To test on Heroku, add and commit your changes, then push to the heroku remote: 

{% highlight bash %}
$ git add -A
$ git commit -m "shorten urls"
$ git push heroku master
$ heroku open
{% endhighlight %}

You should now be able to submit a URL and have a shortened one returned! Following these shortened URLs won't redirect us to the original URLs just yet. Let's fix that.

The shortened link we've generated above will be matched to the `/:key` path in our application. We check that the supplied key matches a record in the database, and if it does, we redirect the user to the original (long) URL:

<div class="highlight-header">~/url-shortener/index.js</div>
{% highlight js tabsize=4 %}
app.get('/:key', function (req, res) {
	// Check for key and redirect
	db.one('select * from entry where key = $1', req.params.key)
	.then(function (entry) {
		res.redirect(entry.url);
	})
	.catch(function () {
		// no entry found, redirect home
		res.redirect('/');
	});
});
{% endhighlight %}

Give it another test on your local and Heroku set up. You should now have a fully functioning, albiet style-less, URL shortening service. Check out the source code below for some added style!

<p class="text-center">
	<a href="{{ page.project_link }}" class="btn btn-dark" target="_blank"><i class="fa fa-github"></i> View the source on GitHub</a>
</p>

## Conclusion
I hope you enjoyed following along. Not only did we manage to build a fully functioning URL shortening service, but we've also familiarized ourselves with the tools to take a project like this to the next level.

Consider adding more features to what we've built here. Add a click tracker to count how many times a shortened link has been accessed, or validate submitted URLs to ensure they point to an existing site, or allow the user to supply their own short-code for a URL...

It's all up to you. Enjoy!

## Useful links
- [Getting Started on Heroku with Node.js][getting started]{:target="_blank"} - heroku.com
- [Learn by Example - pg-promise][learn example]{:target="_blank"} - Vitaly Tomilov

[part 1]: /url-shortener-express-heroku-part-1
[heroku]: https://heroku.com
[node env]: https://nodejs.org/api/process.html#process_process_env
[git]: https://git-scm.com/docs/gittutorial
[heroku signup]: https://signup.heroku.com
[heroku cli]: https://devcenter.heroku.com/articles/heroku-cli
[postgres]: https://www.postgresql.org/
[postgres install]: https://www.postgresql.org/download/
[install git]: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
[procfile]: https://devcenter.heroku.com/articles/procfile
[pg-promise]: https://github.com/vitaly-t/pg-promise
[random-key]: https://www.npmjs.com/package/random-key
[body-parser]: https://www.npmjs.com/package/body-parser
[getting started]: https://devcenter.heroku.com/articles/getting-started-with-nodejs#introduction
[learn example]: https://github.com/vitaly-t/pg-promise/wiki/Learn-by-Example
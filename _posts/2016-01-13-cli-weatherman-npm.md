---
layout: post
title: "Writing a command-line weatherman and publishing to npm"
date: 2016-01-13 15:54:00
categories: [node.js, npm]
project_link: https://github.com/smarulanda/cli-weatherman
---

Command-line utilities can be intimidating to even the most seasoned of web developers. We tend to get comfortable with merely a passing knowledge of the shell. An `ssh` here, a `cd` and `git pull` there. Maybe a `/etc/init.d/apache2 restart` if things get really hairy.

This tutorial won't teach you any fancy [CLI][cli] tricks, but it will guide you through writing a useful command-line tool that you can publish and share with the world. With a stronger understanding of how these tools are put together, you'll undoubtedly be more prepared next time you're faced with an unfamiliar command.

## What we're building
We're going to build a command-line weatherman. Its most basic function will be to return the current weather for the user's location, along with a projected 5-day forecast. Like most CLI tools, we'll have the ability to pass in arguments and options.

![Terminal]({{ site.s3 }}/images/2016/01/terminal.png){:class="th"}

You aren't limited to [Bash][bash] or other shell-specific languages when writing command-line tools, most any scripting language is fair game. We'll be writing this tool in JavaScript (Node.js). This will allow us to publish our tool to [npm][npm], the popular package manager.

<p class="text-center">
	<a href="{{ page.project_link }}" class="btn btn-dark" target="_blank"><i class="fa fa-github"></i> View the source on GitHub</a>
</p>

## Setting up a Node.js project
I've covered setting up a Node.js project in my [Amazon price tracker][pricetracker] tutorial, feel free to read through that section, but the basics are as follows:

1. Make sure you've [installed][node] the Node.js runtime. This includes the package manager, npm.
2. Create your project directory. I've called mine `cli-weatherman`.
3. In the project directory run the `npm init` command. The tool will ask you several questions about your project. You can usually stick with the default answers.
4. The tool will generate a `package.json` file. All npm packages require this file.
5. Create the entry point for your application. The `package.json` file defaults to `index.js`, but I've called mine `weatherman.js`.

Your project structure should look like this so far:

{% highlight bash tabsize=4 %}
cli-weatherman/
├── package.json
└── weatherman.js
{% endhighlight %}

## A couple of dependencies
This project will require a couple of npm packages to make our lives easier. Since we'll be making a few HTTP requests to determine the user's IP Geolocation and their weather conditions, we'll include the `request` [module][npm request].

We'll also need to parse any user supplied command-line options or arguments. This can be tricky in any language, but there's an npm [package][npm commander] that makes it dead simple: `commander`.

We want to install these npm packages locally for our project, rather than globally, so we run: 

{% highlight bash %}
$ npm install request commander --save
{% endhighlight %}

This will create a `node_modules` directory with those packages. The `--save` flag will add these dependencies to our `package.json` file.

Our project structure now:

{% highlight bash tabsize=4 %}
cli-weatherman/
├── package.json
├── weatherman.js
└── node_modules/
	├── commander/	# contains package files
	└── request/	# contains package files
{% endhighlight %}

## The APIs
Before we start writing our script, let's take a look at the [REST][rest] APIs we'll be implementing. The first is [freegeoip][freegeoip]. This API will return location information based on the requesting (or supplied) IP address. For example, a user in Seattle could make an HTTP request to `https://freegeoip.net/json` and the service would respond with:

{% highlight json tabsize=4 %}
{
	"ip": "156.74.251.21",
	"country_name": "United States",
	"region_name": "Washington",
	"city": "Seattle",
	"zip_code": "98104",
	"time_zone": "America/Los_Angeles"
}
{% endhighlight %}

We can then grab the `zip_code` field and pass that to our next API, Yahoo's weather [YQL API][yql].

Although there is no shortage of [free][forecast.io] [weather][openweathermap] [APIs][wunderground], the vast majority require an API key. This requirement shouldn't affect personal projects much, but we want to publish our application. This would require us to publish our API key or else require each user to supply their own. That's why we're going with Yahoo's API; they have no key requirement.

Most of Yahoo's APIs are structured around their homegrown query language, YQL. It's quite similar in syntax to [SQL][sql]. To get the weather for Beverly Hills, we would use the query:

{% highlight sql %}
SELECT * FROM weather.forecast WHERE location = 90210
{% endhighlight %}

Properly URL encoded, that query becomes:

{% highlight html %}
https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20weather.forecast%20where%20location%3D90210&format=json
{% endhighlight %}

Copy that link into your address bar and check the response. Amongst a plethora of data you should see what we're looking for:

{% highlight json tabsize=4 %}
...
"condition": {
	"code": "34",
	"date": "Wed, 13 Jan 2016 11:51 am PST",
	"temp": "62",
	"text": "Fair"
},
...
"forecast": [
	{
		"code": "30",
		"date": "13 Jan 2016",
		"day": "Wed",
		"high": "62",
		"low": "46",
		"text": "Partly Cloudy"
	},
	...
]
...
{% endhighlight %}

## Require the packages
Let's dive into our `weatherman.js` file. First, we're going to use the CommonJS `require` [keyword][node require] to bring in all the Node packages this project uses:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
#!/usr/bin/env node

var program = require('commander');
var request = require('request');
var querystring = require('querystring');
var pkg = require('./package.json');
{% endhighlight %}

The first line, `#!/usr/bin/env node`, will tell our shell to execute the script in a `node` environment.

The `commander` and `request` modules were installed through `npm` earlier. We'll use the `querystring` module to build the YQL query; it is a built-in Node.js utility so we don't have to `npm install` it.

Finally, by importing our `package.json` file, we can programmatically access our project's metadata. We'll see this in action in just a bit.

## Taking command
Above, we assigned the `commander` package to the variable `program`. Browsing the package's [documentation][npm commander] we can tailor it to our needs:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
...
program
	.version(pkg.version)
	.option('-C, --celsius', 'Show temperatures in celsius')
	.option('-z, --zip <zip>', 'Return weather for a specific ZIP code')
	.parse(process.argv);
{% endhighlight %}

This greatly simplifies the process of parsing command line arguments. Here we check if the user has supplied the `-C/--celsius` option; we'll use this to display the weather in Celsius rather than the default, Fahrenheit.

We'll also check if a `-z/--zip` has been supplied. This will allow us to bypass the `freegeoip` API and pass the location directly to the `YQL` API.

If supplied, these arguments will get mapped to `program.celsius` and `program.zip`.

## Geolocation
Now that we've gotten the `commander` set up, our first step is to check whether or not a ZIP code was supplied. If one is supplied, we pass it to a function we have yet to write called `getWeather()`. Otherwise, we make a request to `freegeoip`, get the `zip_code` response, and pass that to `getWeather()`.

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
...
if (program.zip) {
	getWeather(program.zip);
}
else {
	request('http://freegeoip.net/json', function(error, response, body) {
		if (!error && response.statusCode == 200) {
			var data = JSON.parse(body);
			getWeather(data.zip_code);
		}
	});
}
{% endhighlight %}

Above, we make use of the `request` module. It takes in a URL and a callback method to execute. We check for a successfully completed request, parse the JSON response, and extract the parameter(s) we need.

## Rain or shine
The Yahoo weather endpoint URL is a bit more involved than the `freegeoip` one. We'll make use of the `querystring` module to encode the URL properly:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
function getWeather(zip) {
	var yqlUrl = 'https://query.yahooapis.com/v1/public/yql?' 
	var yqlArgs = {
		q: 'select * from weather.forecast where location=' + zip,
		format: 'json'
	};

	yqlUrl += querystring.stringify(yqlArgs);
}
{% endhighlight %}

Now that we have the proper endpoint for the given ZIP code, we make a `request` to the Yahoo service, much like the request we made above:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
function getWeather(zip) {
	...
	request(yqlUrl, function(error, response, body) {
		if (!error && response.statusCode == 200) {
			var data = JSON.parse(body);
		}
	}
}
{% endhighlight %}

From the API's lengthy response, we're going to want to get a few key pieces of information, notably: title, temperature, condition, units, and forecast. Those are nested in the following objects:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js %}
...
var data = JSON.parse(body);

var channel = data.query.results.channel;
var title = channel.item.title;
var temp = channel.item.condition.temp;
var unit = channel.units.temperature;
var text = channel.item.condition.text;
var forecast = channel.item.forecast;
{% endhighlight %}

Finally, we want to display all these parameters in a legible way. By using `console.log` we can output text to the command-line:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
...
console.log('');
console.log(title + ':');
console.log('%s, %s °%s', text, temp, unit);

console.log('');
console.log('Forecast:');

for (var i = 0; i < forecast.length; i++) {
	var fc = forecast[i];
	console.log('%s - %s, %s°/%s°', fc.day, fc.text, fc.high, fc.low);
};

console.log('');
{% endhighlight %}

Notice that the forecast is stored in an array. We need to loop through it and output each forecasted day's information.

## Running it
If you've followed along to this point, great! If not, feel free to grab a copy of this project from the GitHub [repo]({{page.project_link}}). Once you're in the project directory, from the command-line run:

{% highlight bash %}
$ node weatherman.js
{% endhighlight %}

Or specify that you'd like the weather at the White House, in degrees Celsius:
{% highlight bash %}
$ node weatherman.js -C -z 20500
{% endhighlight %}

The command-line will return the current weather and the 5-day forecast. Fantastic, but this method may not be entirely intuitive to those who will be using the application. We want users to install this application globally and access it via the `weatherman` keyword.

Let's dive back into our `package.json` file and add this bit:

{% highlight js tabsize=4 %}
...
"bin": {
	"weatherman": "weatherman.js"
},
...
{% endhighlight %}

Take a look at the npm [documentation][npm bin] to see exactly how the `bin` field works.

## Publishing to npm
You can publish any directory that has a valid `package.json` file to npm. First, [create][npm account] an account. This can also be accomplished from the command-line via `npm adduser`.

If you created an account through the website, you'll want to `npm login` from the command-line.

You'll probably want to use the search feature at [npmjs.com][npm] to make sure you have a unique `name` in your `package.json`. I've already used [cli-weatherman][npm weatherman] for this project, but I'm sure you can think of something clever.

Finally, run `npm publish` to publish the package.

Test by going to `https://npmjs.com/package/<package>`. You should (hopefully) see the page for your package.

## Installing the package
Let's see if all that hard work paid off. Run the following, replacing `<package>` with your published package name:

{% highlight bash %}
$ npm install -g <package>
{% endhighlight %}

The `-g` flag will install the package globally on your system, allowing you to run `weatherman` from any directory.

## Useful links
- [Publishing npm packages](https://docs.npmjs.com/getting-started/publishing-npm-packages){:target="_blank"} - npmjs
- [Publishing a simple package to npm](http://evanhahn.com/make-an-npm-baby/){:target="_blank"} - Evan Hahn

[cli]: https://en.wikipedia.org/wiki/Command-line_interface
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[npm]: https://www.npmjs.com
[npm weatherman]: https://www.npmjs.com/package/cli-weatherman
[pricetracker]: /amazon-price-tracker-pushbullet
[node]: https://nodejs.org
[npm request]: https://www.npmjs.com/package/request
[npm commander]: https://www.npmjs.com/package/commander
[rest]: https://en.wikipedia.org/wiki/Representational_state_transfer
[freegeoip]: https://freegeoip.net
[yql]: https://developer.yahoo.com/weather/
[forecast.io]: https://developer.forecast.io/docs/v2
[openweathermap]: http://openweathermap.org/api
[wunderground]: http://www.wunderground.com/weather/api/
[sql]: https://en.wikipedia.org/wiki/SQL
[node require]: http://fredkschott.com/post/2014/06/require-and-the-module-system/
[npm bin]: https://docs.npmjs.com/files/package.json#bin
[npm account]: https://www.npmjs.com/signup
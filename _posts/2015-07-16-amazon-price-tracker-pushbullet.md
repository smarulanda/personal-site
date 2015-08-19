---
layout: post
title:  "Writing an Amazon price tracker with Pushbullet notifications in Node.js"
date:   2015-07-16 12:31:27
categories: [node.js, pushbullet]
---

In this tutorial, we're going to write a small [Node.js][nodejs] script that will check if an Amazon product has dropped below a certain price. We'll have the script ping the product page every minute, and if the price has dropped enough, we'll send out a [Pushbullet][pushbullet] notification.

<p class="text-center">
	<a href="https://github.com/smarulanda/pricetracker" class="btn btn-dark" target="_blank"><i class="fa fa-github"></i> View the source on GitHub</a>
</p>

## Node.js
Node.js has become quite popular in the past several years, and with good reason. Not only does it allow developers to use JavaScript across the stack, but it enables them to create real-time websites with push capability. Although we're not going to dive into the complexities of WebSockets, scalability, or the event-loop, it's worth [taking a look][whynode] at why the environment has become so popular.

Once you've downloaded and installed Node.js from their [website][nodejs] you should be good to go. The install also includes `npm`, the Node Package Manager. Much like `gem` for Ruby, `npm` allows us to easily manage dependencies in our Node applications.

## Pushbullet
[Pushbullet][pushbullet] is a fantastic web service. In a nutshell, once their app is installed on your device(s) you can have your notifications mirrored across them. I use it mainly to view and respond to incoming text messages straight from my browser without having to reach for my phone, which might be in another room! Pushbullet also offers a simple [API][pushbullet api] to programatically send your own pushes. That's what we're going to do.

## Setting up app.js and package.json
OK, let's start building our project. Let's first create a directory for our app to live in. Any name should work here, so I'll go with the obvious: `pricetracker`. Inside our `pricetracker` directory let's create our JavaScript file: `app.js`. As it's a fairly simple project we're building, all of our code will live in this one `.js` file.

If you've taken a peek at the GitHub [repo][repo] for this project, you may have noticed a `package.json` file. This works much in the same way a [Gemfile][gemfile] works for a Ruby project. It will contain metadata about the project, but more importantly it will include a list of dependencies to install from `npm`.

You don't have to write the `package.json` file from scratch. Navigate to your project directory from the command line and run `npm init`. The program will prompt you to answer a few questions and will generate the file for you.

## Getting the product price
The most important step in our project is to be able to pull a product's current price from Amazon. Let's start with this very basic script in `app.js` and run through each line to see what's going on.

{% highlight javascript tabsize=3 %}
var request = require('request');
var fs = require('fs');

var asin = 'B00MU2DMX8';
var amzn_url = 'http://www.amazon.com/dp/' + asin;

request(amzn_url, function(error, response, body) {
	fs.writeFile('product.html', body, function(error) {
		console.log('Page saved!');
	});
});
{% endhighlight %}

The first two lines use the [CommonJS][commonjs] built-in `require` function to include modules that exist in separate files. The `request` module gives us a simple way to make http calls. We'll use this to retrieve the product page's html. The `fs` module allows us to access the file system. This will come in handy in just a bit.

The next two variables we are setting are `asin` and `amzn_url`. These will reference the Amazon Standard Identification Number: the unique ID given to each product on Amazon. You can find this in your desired product page's url or in the Product Details section.

![Product Details]({{ site.s3 }}/images/2015/07/product-details.png){:class="th"}

The product in this case is a [Lego version][lego tumbler] of the Dark Knight Tumbler. It's been sitting in my wish list for a while. Please feel free to buy me one.

The final code block in the script will leverage the modules we included earlier. It will request the page located at `amzn_url` and use the `fs` method `writeFile` to write the request's `body` to a file `product.html`.

## Scraping the HTML
So now we have the page's html contents saved to our computer, but how do we extract the product's price from thousands of lines of markup? First, we open up the `product.html` file in a text editor and do some sleuthing. It turns out that the price shows up in a conveniently labeled `<span id="actualPriceValue">`.

![Actual Price Value]({{ site.s3 }}/images/2015/07/actual-price-value.png){:class="th"}

Now, grabbing the price using something like jQuery would be very simple: `$('#actualPriceValue').text()`, but we have to keep in mind that Node is server-side JavaScript, so there is no actual underlying [Document Object Model][dom]. We're just viewing a textual representation of the DOM.

Luckily there's an existing module that can teach our server HTML, it's called [cheerio][cheerio]. We can feed it an HTML string, like the one our `request` module returned, and perform jQuery-like operations on it. 

Once you `require()` it in your script, don't forget to run `npm install cheerio` from the command line.

{% highlight javascript tabsize=3 %}
...
var cheerio = require('cheerio');
...

checkPrice();

function checkPrice() {
	request(amzn_url, function(error, response, body) {
		var $ = cheerio.load(body);
		var list_price = $('#actualPriceValue').text();
		var stripped_price = list_price.replace('$', '').replace(',', '');	// remove leading $ and any commas

		console.log(stripped_price);	// 199.95
	});

	setTimeout(checkPrice, 60000);	// 60000 ms == 1 min
}
{% endhighlight %}

You'll notice that we wrapped our `request()` block in a function `checkPrice()`. We're going to want to continuously monitor the price, so by making the request callable we can use JavaScript's `setTimeout()` method to call the function every `x` milliseconds.

## Sending a Pushbullet notification
So far our script is only printing out the product's price to the console every minute. How do we trigger a Pushbullet notification when the price has dropped below our target price? Once again we're in luck! Someone has already written a Pushbullet API [module][node-pushbullet].

{% highlight javascript tabsize=3 %}
...
var pb = require('pushbullet');
...

function checkPrice() {
	request(amzn_url, function(error, response, body) {
		...
		if (stripped_price <= price) {
			sendPush();
		}
	});
}

function sendPush() {
	var pusher = new pb("xxxxx");	// Your pushbullet token

	pusher.note(null, "Amazon Price Watch", "Price drop for: " + amzn_url, function(error, response) {
		process.exit();		// kill the script once push is sent
	});
}
{% endhighlight %}

Simple enough. The `note()` method allows us to send a new pushbullet notification. We'll give it a subject and a link to the product page. We'll also kill the entire script once the push is sent, so we don't keep getting pushes during each `setTimeout` interval.

## Private tokens in source code?
You may have noticed in the previous example that the [Pushbullet Access Token][pushbullet token] is hard-coded. This is mostly fine if you're the only one who has access to your source code, but what if you want to share your code with the world?

You could always leave placeholders in the source `"xxxxx"` and let users know that they'll have to replace these before they run the script. But we want this script to work out of the box.

Check out the [source code][repo] for this project. I take advantage of a module called `prompt`. Instead of having the user hard-code variables like their pushbullet token, product ID, or desired price, we can instead prompt them from the command line.

{% highlight javascript tabsize=3 %}
var schema = {
	properties: {
		asin: {
			description: 'Enter the product ASIN',
			type: 'string',
			required: true
		},
		...
	}
};

prompt.start();

prompt.get(schema, function (error, result) {
	asin = result.asin;
	price = result.price;
	pb_token = result.pb_token;
	...
});
{% endhighlight %}

Now we just run `node app.js` from the command line, punch in our variables, and sit back while node does the heavy lifting! You can verify that it's working by entering a desired price that is higher than the product's actual price. You should get a Pushbullet notification right away.

## Conclusion
This tutorial should give you the basic skills to not only build the price tracker, but any kind of web scraper. Maybe you want to check if the front page of a site has changed, or if an out of stock item has become available. You can do that!

Happy coding!

[nodejs]: http://nodejs.org
[pushbullet]: http://pushbullet.com
[whynode]: http://chetansurpur.com/blog/2010/10/why-node-js-is-totally-awesome.html
[pushbullet api]: https://docs.pushbullet.com/
[repo]: https://github.com/smarulanda/pricetracker
[gemfile]: http://bundler.io/v1.5/gemfile.html
[commonjs]: https://en.wikipedia.org/wiki/CommonJS
[lego tumbler]: http://www.amazon.com/dp/B00MU2DMX8
[dom]: https://en.wikipedia.org/wiki/Document_Object_Model
[cheerio]: https://github.com/cheeriojs/cheerio
[node-pushbullet]: https://github.com/alexwhitman/node-pushbullet-api
[pushbullet token]: https://www.pushbullet.com/#settings
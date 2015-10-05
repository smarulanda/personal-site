---
layout: post
title:  "Writing a simple jQuery plugin"
date:   2015-03-12 16:57:21
categories: [jquery, javascript, velociraptors]
project_link: https://github.com/smarulanda/jquery.simplePagination
---

[jQuery][jquery] is everywhere. Once you're familiar with the syntax it makes DOM manipulation and interactivity a snap. Thanks to its ease-of-use there is no shortage of developers who rely on jQuery. This means there are plenty of free, open-source, and powerful jQuery plugins just waiting to be used in your project.

Say you're looking to replace the browser's built in `alert()` dialog. There's a [plugin][alertify] for that. Maybe you want an interactive file uploader. There's a [plugin][file upload] for that. Hell, say you want velociraptors to spontaneously appear on your page. Yep, [plugin][raptorize] for that. And you get my point.

## Why?

So why write your own plugin? If there are velociraptor plugins, then there must certainly exist a plugin for any other need. Right? 

Probably.

But rolling your own plugin can give you a completely tailor-made solution for your particular need. It will also give you a fundamentally stronger understanding of how your entire project fits together. It's something every developer, aspiring or experienced, should be comfortable doing.

## What we're building

We're going to be building a small plugin that can [paginate][pagination] an HTML table. The plugin will truncate the table to the desired number of rows (a default value or a user-supplied one), display the total number of records, the current page, and supply "previous" and "next" buttons.

The following links will take you to a working demo of the finished plugin and the source code on GitHub.

<p class="text-center">
	<a href="/demo/jquery.simplePagination.html" class="btn btn-primary"><i class="fa fa-laptop"></i> Demo</a>
	<a href="{{ page.project_link }}" class="btn btn-dark" target="_blank"><i class="fa fa-github"></i> GitHub</a>
</p>

## Getting started

The actual plugin will reside in a single javascript file, but we'll need a page to test it on. Let's include a local copy of jQuery as well, though this isn't particularly necessary. There are plenty of jQuery CDNs and all modern browsers are great at caching these resources.

This is what our project structure should look like. The `index.html` file will be our test page. You can grab the latest copy of jQuery [here][jquery download].

{% highlight bash tabsize=4 %}
project
├── index.html
└── js
|	├── jquery-1.11.2.min.js
|	└── jquery.simplePagination.js
{% endhighlight %}

Let's go ahead and fill in our `index.html` page with some boilerplate HTML. We'll also include jQuery and our empty plugin file in the `<head>` tag (although some prefer to place their scripts right before the closing `</body>` tag).

<div class="highlight-header">~/project/index.html</div>
{% highlight html tabsize=3%}
<!DOCTYPE html>
<html>
<head>
	<title>Pagination Plugin</title>

	<script src="js/jquery-1.11.2.min.js"></script>
	<script src="js/jquery.simplePagination.js"></script>
</head>
<body>
	This is our test page.
</body>
</html>
{% endhighlight %}

Opening the `index.html` file in your browser should now show you a nearly empty page with the text `This is our test page`.

You're going to want to add in a large-ish table to the `<body>`. You can generate dummy table data using sites like [this][dummy data], or feel free to view-source and copy from my [demo][demo] page!

## Plugin structure

It doesn't take much to get the basic jQuery plugin structure in place. Take a look at the following skeleton code:

<div class="highlight-header">~/project/js/jquery.simplePagination.js</div>
{% highlight javascript tabsize=3 %}
(function($) {

	$.fn.simplePagination = function() {
		// Our plugin code will go here!
	}

}(jQuery));
{% endhighlight %}

By wrapping our plugin with `(function($) {})` we are following the javascript module pattern. This allows everything in our plugin to run within a [closure][closure], which means all of our code lives safely outside of the global namespace and we won't find ourselves colliding with any other javascript on the page.

jQuery allows us to define our plugin using `$.fn` followed by our chosen name, which will be `simplePagination`.

**Don't worry!** A strong understanding of javascript namespaces, closures, etc. isn't necessary for this project. Slowly familiarizing yourself with these terms is all part of the game!

## Adding functionality

Before getting too far into coding our paginator, let's make sure we understand what is going on under the hood by writing a plugin that performs a simpler task: changing text color.

{% highlight javascript tabsize=3 %}
(function($) {

	$.fn.simpleColorizer = function() {

		return this.each(function() {
			$(this).css("color", "red");
		});

	}

}(jQuery));
{% endhighlight %}

Believe it or not, that is a complete jQuery plugin. 

We use jQuery's `$.each()` [method][jquery each] in order to iterate over every matched element and apply our plugin to each one. Once inside the `each` we can refer to our matched element using `$(this)`. Here we are using the jQuery's `css()` method to change our selected element's color to red.

Finally, we return `this` in order to allow for [method chaining][method chaining].

I've attached a simple `onclick` event to the "Run" button below. Ignoring some class attributes and an icon font it looks like this:

{% highlight html %}
<button onclick="$('h2').simpleColorizer()">Run</button>
{% endhighlight %}

Click the button and it will attach the `simpleColorizer` plugin we just wrote to every `h2` element on the page. Try it out!

<p class="text-center">
	<button class="btn btn-primary" onclick="$('h2').simpleColorizer()"><i class="fa fa-terminal"></i> Run</button>
</p>

## Give them options!

Alright, let's jump back into our pagination plugin. The point of our plugin is to limit the number of table rows our users see at a given time. So what's a good number? Five, ten, twenty? What works for one user might not work for everyone. We might even have multiple tables on the same page that require different settings!

Our plugin should be able to provide a default value, but also the ability to override that value without having to edit the source. So how do we allow for that? Check it out:

<div class="highlight-header">~/project/js/jquery.simplePagination.js</div>
{% highlight javascript tabsize=3 %}
(function($) {

	$.fn.simplePagination = function(options) {
		
		var defaults = {
			perPage: 5,
			currentPage: 1,
			previousButtonText: 'Previous',
			nextButtonText: 'Next'
		};

		var settings = $.extend({}, defaults, options);

		return this.each(function() {
			// Our plugin code will go here!
		}

	}

}(jQuery));
{% endhighlight %}

We've created a `defaults` array with some sane defaults. The `perPage` option will default to `5` if no option is supplied. Let's also add a `currentPage` option. This will allow the user to determine which page is displayed first.

**Note:** I'm using the value `1` in `currentPage` to refer to the first page, but you could just as easily choose to implement a [zero-based index][zero-based index] for your pages. That all gets sorted out in our plugin code.

Next, we use jQuery's `$.extend` method to merge any user-supplied values with our default values. We assign this out to the `settings` object variable which can later be referred to within our plugin code.

## Adding to the DOM

Our "Next" and "Previous" buttons don't yet exist in the [DOM][DOM] so let's build them into our plugin.

<div class="highlight-header">~/project/js/jquery.simplePagination.js</div>
{% highlight javascript tabsize=3 %}
...
return this.each(function() {

	var container = document.createElement('div');	// contains buttons and text
	var bPrevious = document.createElement('button');	// previous button
	var bNext = document.createElement('button');	// next button
	var of = document.createElement('span');	// displays page of pages

	/* Get text from our settings, this could be default or user-supplied */
	bPrevious.innerHTML = settings.previousButtonText;
	bNext.innerHTML = settings.nextButtonText;
	
	/* Fill our container */
	container.appendChild(bPrevious);
	container.appendChild(of);
	container.appendChild(bNext);

	$(this).after(container);	// Place the container below the table

}
...
{% endhighlight %}

At this point our plugin will create a container `<div>` with children elements that include a "Previous" button, a page tracker, and a "Next" button. The container gets injected into the DOM right after the selected table.

You can add the following code to your `index.html` file to make sure it all works.

<div class="highlight-header">~/project/index.html</div>
{% highlight html tabsize=3 %}
<!-- This can go anywhere after your jQuery and plugin scripts -->
<script>
	$(function() {
		// You can give your table an ID and reference it here
		$('table').simplePagination({
			perPage: 5,	// these options aren't necessary
			currentPage: 1 	// but this is how you would override the defaults
		});
	});
</script>
{% endhighlight %}

## Event listeners

So now we have our buttons displaying after the table, but clicking them still doesn't do anything, and our table is still showing every row. We need to add some click listeners to our buttons!

<div class="highlight-header">~/project/js/jquery.simplePagination.js</div>
{% highlight javascript tabsize=3 %}
...
$(this).after(container);	// Place the container below the table

var $rows = $('tbody tr', this);	// A jQuery collection of table rows
var pages = Math.ceil($rows.length/settings.perPage);	// Calculating the total number of pages

update();

$(bNext).click(function() {
	if (settings.currentPage + 1 > pages) {
		settings.currentPage = pages;
	} else {
		settings.currentPage++;
	}

	update();
});

$(bPrevious).click(function() {
	if (settings.currentPage - 1 < 1) {
		settings.currentPage = 1;
	} else {
		settings.currentPage--;
	}

	update();
});
...
{% endhighlight %}

Adding that code to our plugin won't do much yet, but bear with me. By adding click listeners to our `$(bNext)` and `$(bPrevious)` we can increment or decrement the `currentPage` item in our `settings` object. 

The `if() {}` statements allow us to catch whenever the `currentPage` dips below `1` or goes above the total page number (`pages`).

## The update method

We've peppered our plugin with a few references to `update()` which we have yet to define. This method will perform all of our plugin magic based on the `settings` object that we've defined and allowed to be modified by a couple of click listeners.

Let's get to it.

<div class="highlight-header">~/project/js/jquery.simplePagination.js</div>
{% highlight javascript tabsize=3 %}
...
function update() {
	// Figure out what records we are showing on this page
	var from = ((settings.currentPage - 1) * settings.perPage) + 1;
	var to = from + settings.perPage - 1;

	if (to > $rows.length) {
		// If our last page has fewer records than the perPage value
		to = $rows.length;
	}

	$rows.hide();	// Hide every row
	$rows.slice((from-1), to).show();	// Show only the 'from' to 'to' records

	// The text for our page tracker
	of.innerHTML = from + ' to ' + to + ' of ' + $rows.length + ' entries';
	
	// Only show the paginator if there are enough rows to warrant it
	if ($rows.length <= settings.perPage) {
		$(container).hide();
	} else {
		$(container).show();
	}
}
...
{% endhighlight %}

And that's it! After refreshing your `index.html` file, you should have a fully functioning pagination plugin.

If you're having trouble getting the plugin to work please take a look at the [demo][demo] page. You can view the page source here and make sure you've get everything set up correctly.

You can also view the GitHub [repository][repo]. I've added a few more options and a little bit of styling, but the functionality is all there. Please feel free to modify and improve the code to your heart's content!

## Conclusion

We've only just brushed the tip of the jQuery plugin iceberg, but if you follow the best practices that we've stepped through in these examples you'll be building your own DRY, extensible, and production-ready plugins in no time.

Just keep plugging away.

## Useful links

- [How to Create a Basic Plugin][how to plugin]{:target="_blank"} - jquery.com
- [How to Create a jQuery Plugin][how to plugin2]{:target="_blank"} - Kyle Jasso, The Brolik Blog
- [Essential jQuery Plugin Patterns][essential patterns]{:target="_blank"} - Addy Osmani, Smashing Magazine

[jquery]: http://jquery.com
[alertify]: http://fabien-d.github.io/alertify.js/
[file upload]: http://blueimp.github.com/jQuery-File-Upload/
[raptorize]: http://zurb.com/playground/jquery-raptorize
[pagination]: http://en.wikipedia.org/wiki/Pagination#Pagination_in_web_content
[jquery download]: https://code.jquery.com/
[dummy data]: http://dummydata.me/
[demo]: /demo/jquery.simplePagination.html
[closure]: http://www.adequatelygood.com/JavaScript-Module-Pattern-In-Depth.html
[jquery each]: https://api.jquery.com/each/
[method chaining]: http://schier.co/blog/2013/11/14/method-chaining-in-javascript.html
[zero-based index]: http://en.wikipedia.org/wiki/Zero-based_numbering
[DOM]: http://en.wikipedia.org/wiki/Document_Object_Model
[repo]: https://github.com/smarulanda/jquery.simplePagination
[how to plugin]: https://learn.jquery.com/plugins/basic-plugin-creation/
[essential patterns]: http://www.smashingmagazine.com/2011/10/11/essential-jquery-plugin-patterns/
[how to plugin2]: http://brolik.com/blog/how-to-create-a-jquery-plugin/

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
<script>
	(function($) {

		$.fn.simpleColorizer = function() {
			this.each( function() {
				$(this).css("color", "red");
			});
		}

	}(jQuery));
</script>
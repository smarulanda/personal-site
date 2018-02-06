---
layout: post
title: "Debugging the command-line weatherman"
date: 2018-02-05 19:54:00
categories: [node.js, npm]
project_link: https://github.com/smarulanda/cli-weatherman
---

[Third-party APIs][third-party] allow us to create rich and immersive web applications by giving us access to data that we otherwise couldn't produce ourselves. Though there are many benefits to using outside libraries, ultimately that code is outside our control, and can easily compromise the stability of our application. I recently experienced this firsthand.

A reader of my blog contacted me to let me know that my [command-line weather forecaster][weatherman] had stopped working. Instead of outputting the local weather, the application returned the following error:

![Terminal]({{ site.s3 }}/images/2018/02/weatherman-error.png){:class="th"}

I hadn't modified the code since releasing the tutorial, so my assumption was one of the third-party APIs I had used was acting up.

## Digging into the code
After re-cloning the github repository for the project, I made my way to the offending block of code:

<p class="text-center">
	<a href="{{ page.project_link }}" class="btn btn-dark" target="_blank"><i class="fa fa-github"></i> View the source on GitHub</a>
</p>

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
...
request(yqlUrl, function(error, response, body) {
	if (!error && response.statusCode == 200) {
		var data = JSON.parse(body);

		var channel = data.query.results.channel;
		var title = channel.item.title;
...
{% endhighlight %}

The fact that the error occurs within the `if` statement tells us that our request to the YQL endpoint is successful, but it's not returning the response that we're expecting.

Let's output the result of the request to our console so we can dig a little deeper. Modifying the code:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
...
request(yqlUrl, function(error, response, body) {
	if (!error && response.statusCode == 200) {
		var data = JSON.parse(body);
		return console.log(data.query.results);
...
{% endhighlight %}

Running `node weatherman.js` returns:

![Terminal]({{ site.s3 }}/images/2018/02/weatherman-cli.png){:class="th"}

Now we're getting somewhere. Our code is erroring out because it's looking for a `channel.item`, that no longer exists. All we have in the YQL response is information about the units we're using; there's no real data.

So where do we go from here?

## Reading the documentation
If the first few google results or Stack Overflow answers aren't helpful, the next best bet is to comb through any documentation you can find. Pulling up the [Yahoo Weather documentation][documentation] yields some helpful clues:

> For the Weather RSS feed there are two parameters:
> - w for WOEID.
> - u for degrees units (Fahrenheit or Celsius).
>
> The [WOEID][woeid] parameter w is required. Use this parameter to indicate the location for the weather forecast as a WOEID.

Looking back through the code, we see that the call we're making to the YQL API supplies the following parameters:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
...
var yqlArgs = {
	q: 'select * from weather.forecast where location=' + zip + ' and u=' + (program.celsius ? '"c"' : '"f"'),
	format: 'json'
};
...
{% endhighlight %}

We've made use of the `u` parameter to choose between Fahrenheit and Celsius, but it appears the `location` parameter is no longer supported. Instead we need to use a WOEID. You can read more about Where On Earth Identifiers [here][woeid].

## From Zip to WOEID
Since the Yahoo Weather API will no longer directly accept a Zip code as a parameter, we'll need to figure out a way to turn our Zip code into the correct WOEID.

We can once again leverage the YQL datatables to solve our problem. I recommend playing around with the [YQL console][yql console] to see all the data available. In our case, instead of querying the `weather.forecast` table, we need to query `geo.places`:

![YQL Console]({{ site.s3 }}/images/2018/02/yql-console.png){:class="th"}

Without adding a `geo.places(1)` the YQL API will give us WOEIDs for every result to the search `90210`. We only need the first one.

## Tying it all together
How do we get the two YQL queries to play nicely? One option is to run them sequentially, and pipe the result of the `geo.places` query into the `weather.forecast` query. Although that would work fine, we can actually combine them into one nested query:

{% highlight sql %}
SELECT * FROM weather.forecast WHERE woeid IN (SELECT woeid from geo.places(1) WHERE text="90210")
{% endhighlight %}

Modifying our code to make the corrected API call:

<div class="highlight-header">~/cli-weatherman/weatherman.js</div>
{% highlight js tabsize=4 %}
function getWeather(zip) {
	var geoQuery = 'select woeid from geo.places(1) where text="' + zip + '"';

	var yqlArgs = {
		q: 'select * from weather.forecast where woeid in (' + geoQuery + ') and u=' + (program.celsius ? '"c"' : '"f"'),
		format: 'json'
	};
...
}
{% endhighlight %}

Finally, checking our application:

![Terminal]({{ site.s3 }}/images/2018/02/weatherman-cli2.png){:class="th"}

It works! 😎

## Conclusion
Reliance on third-party APIs is all but necessary in today's software development scene. Though most robust libraries do their best to make non-breaking changes in their updates, we need to be prepared to find solutions when something does go awry.

[third-party]: https://www.reddit.com/r/webdev/comments/3wrswc/what_are_some_fun_apis_to_play_with/
[weatherman]: /cli-weatherman-npm/
[documentation]: https://developer.yahoo.com/weather/documentation.html
[woeid]: https://developer.yahoo.com/geo/geoplanet/guide/concepts.html
[yql console]: https://developer.yahoo.com/yql/
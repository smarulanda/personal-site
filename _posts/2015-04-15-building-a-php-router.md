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

<p class="text-center">
	<a href="https://github.com/smarulanda/Siesta" class="btn btn-dark" target="_blank"><i class="fa fa-github"></i> View the source on GitHub</a>
</p>

## The .htaccess file

An `.htaccess` file lives in the directory level of your application. They allows us to override the server's global configuration for the particular directory. There are many use cases for including an `.htaccess` file, the most common being authorization/authentication for the directory. We can also use it to blacklist certain IP addresses, set custom error responses, and what we'll be focusing on in this project: rewriting URLs.

Let's take a look at this `.htaccess` file. These 4 lines are all we'll need for this project.

{% highlight apache tabsize=3 %}
RewriteEngine on
RewriteCond %{REQUEST_FILENAME} !-d
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule . index.php [L]
{% endhighlight %}

The first line `RewriteEngine on` enables the rewrite engine. The second and third lines `RewriteCond %{REQUEST_FILENAME} !-d` and `RewriteCond %{REQUEST_FILENAME} !-f` check for existing directories (-d) and files (-f). The last line `RewriteRule . index.php [L]` does the actual rewriting/redirecting.

Now when your server receives a request, such as `http://example.com/page`, it will be processed as though it were being requested to the `index.php` file: `http://example.com/index.php/page`. So every incoming request hits the same file. This will make it much easier to write a routing class.

## The PHP Class

Since our routing class allows for RESTful URLs, let's give it a clever name. How about Siesta? Perfect.

The class should be able to distinguish the type of incoming HTTP request. A `GET` request usually returns one or many resources, `POST` creates a new resource, `PUT` or `PATCH` update an existing resource, and `DELETE` deletes a resource.

{% highlight php startinline tabsize=3 %}
class Siesta {
	protected $base_path;
	protected $request_uri;
	protected $request_method;
	protected $http_methods = array('get', 'post', 'put', 'patch', 'delete');

	function __construct($base_path = '') {
		$this->base_path = $base_path;

		// Remove query string and trim trailing slash
		$this->request_uri = rtrim(strtok($_SERVER['REQUEST_URI'], '?'), '/');
		$this->request_method = $this->_determine_http_method();
	}

	private function _determine_http_method() {
		$method = strtolower($_SERVER['REQUEST_METHOD']);

		if (in_array($method, $this->http_methods)) return $method;
		return 'get';
	}
}
{% endhighlight %}

Let's take a look at the `__construct()` method. This method will get called automatically whenever a new `Siesta` object is instantiated, usually via `new Siesta()`.

The constructor allows a `$base_path` to be supplied; this can save a bit of repetitive code if the routes share a common base path. We use PHP's `rtrim` and `strtok` methods to remove any query string and trailing slash from a supplied URI. For example the given URI `/foo/bar/page.php/?q=bogus&n=10` would become `/foo/bar/page.php`.

Finally, we call the private method `_determine_http_method()` which checks the `$_SERVER['REQUEST_METHOD']` against the list of predefined `$http_methods`. If none are found, we default to `get`.

## The respond method

The `__construct()` method already does a lot of work for us. Just by instantiating the class we already have access to the `$request_uri` and the `$request_method`. Now let's write a method to respond to incoming requests.

{% highlight php startinline tabsize=3 %}
public function respond($method, $route, $callable) {
	$method = strtolower($method);

	if ($route == '/') $route = $this->base_path;
	else $route = $this->base_path . $route;

	if ($method == $this->request_method && $route == $this->request_uri) {
		call_user_func_array($callable, array());
	}
}
{% endhighlight %}

The `respond()` method accepts three parameters. The `$method` parameter is the request type we want to respond to: `POST`, `DELETE`, etc. The `$route` parameter is the URI we want to respond to: `/superheroes/batman` or `/doctor/12/companion` for example. 

The `$callable` parameter can be a little tricky to understand at first. Essentially, we'll be passing in another `function` or [PHP callable][callable] as a parameter. This can take the form of a string which matches the name of a defined function, or we can supply an anonymous function. We'll see exactly how this works in just a bit.

Back to the `respond()` method. The first `if else` statement checks if our supplied route is simply a root route `/`, if it is then the `$route` is the same as the `$base_path`, otherwise we'll append the supplied `$route` to the `$base_path`.

Finally, we check if the supplied method and URI match the actual method and URI. If they both match, then we execute our callable. This is how the method might get called in practice:

{% highlight php startinline tabsize=3 %}
$siesta = new Siesta();

// Respond to a home page request
$siesta->respond("GET", "/", function() {
	echo "Root path get";
});

// Respond to a delete request at the supplied URI
$siesta->respond("DELETE", "/house/slytherin", function() {
	echo "Removing Slytherin...";
});
{% endhighlight %}

## What about wild cards?

Our class is ready to respond to any request you can throw its way. That's the problem though, we'd have to manually write a response to every possible URI we want to catch. That means routes like `/product/12` and `/product/52` would each need their own response code block. Not very [DRY][dry] is it?

What if instead we supply a `$route` along the lines of `/product/(int:id)`, where `int` means we are looking for an integer and `id` is the variable we want to assign that integer to. Now we can write just one response block and use the `$id` variable within our `$callable`. That might look something like this:

{% highlight php startinline tabsize=3 %}
$siesta = new Siesta();

$siesta->respond("GET", "/person/(int:id)", function($id) {
	echo "You found person " . $id;
});
{% endhighlight %}

There are two types of wildcards we'll want to match: an integer and anything else. Let's add a class member variable to Siesta for these two situations.

{% highlight php startinline tabsize=3 %}
protected $wild_cards = array('int' => '/^[0-9]+$/', 'any' => '/^[0-9A-Za-z]+$/');
{% endhighlight %}

We'll use these regular expressions with PHP's `preg_match` method to determine what type of wild card we're looking at.

Let's write some sample code that compares a wild card delimiter `(int:id)` with a value `12` and returns an array with the pattern `array('id' => '12')`.

{% highlight php startinline tabsize=3 %}
$variables = array();
$delimiter = "(int:id)";
$match = "12";

if ($delimiter[0] == '(' && substr($delimiter, -1) == ')') {
	$strip = str_replace(array('(', ')'), '', $delimiter);
	$exp = explode(':', $strip);

	if (array_key_exists($exp[0], $this->wild_cards)) {
		$pattern = $this->wild_cards[$exp[0]];
		
		if (preg_match($pattern, $match)) {
			$variables[$exp[1]] = $match;
		}
	}
}

return $variables;
{% endhighlight %}

The first `if` statement makes sure the first and last characters of the delimiter are `(` and `)` respectively. Next, we remove those parentheses using `str_replace` and `explode` that string around the `:`. We're left with an array `$exp` with values `int` and `id`.

The next `if` statement checks if the wild card type supplied in the `$delimiter` matches our allowed `$wild_cards`. If it matches we take the related regex pattern from that array.

Finally, the last `if` checks the pattern against the supplied `$match`, in this case `12`. If it does, we add to the `$variables` array; with `id` as the key and `12` as the value.

## Putting it all together

Let's write a private method called `_match_wild_cards()` that takes in one parameter: a route. The route might contain one or several wild card delimiters. The method will check this route against the `$request_uri` and determine if it matches the pattern or not.

Let's retool the sample code above to return an array of key-values for our wild cards.

{% highlight php startinline tabsize=3 %}
private function _match_wild_cards($route) {
	$variables = array();

	$exp_request = explode('/', $this->request_uri);
	$exp_route = explode('/', $route);

	if (count($exp_request) == count($exp_route)) {
		foreach ($exp_route as $key => $value) {
			if ($value == $exp_request[$key]) {
				continue;	// So far the routes are matching
			}
			elseif ($value[0] == '(' && substr($value, -1) == ')') {
				$strip = str_replace(array('(', ')'), '', $value);
				$exp = explode(':', $strip);

				if (array_key_exists($exp[0], $this->wild_cards)) {
					$pattern = $this->wild_cards[$exp[0]];
					
					if (preg_match($pattern, $exp_request[$key])) {
						if (isset($exp[1])) {
							$variables[$exp[1]] = $exp_request[$key];
						}

						continue;	// We have a matching pattern
					}
				}
			}

			return false;	// There is a mis-match
		}

		return $variables;	// All segments match
	}

	return false;	// Catch anything else
}
{% endhighlight %}

We've essentially placed our sample code into a `foreach` loop that goes through each supplied route segment and matches it against each request URI segment. We'll return an `array` if successful, `false` otherwise.

Now we just modify our `respond()` method to check for wild card matches:

{% highlight php startinline tabsize=3 %}
public function respond($method, $route, $callable) {
	$method = strtolower($method);

	if ($route == '/') $route = $this->base_path;
	else $route = $this->base_path . $route;

	$matches = $this->_match_wild_cards($route);

	if (is_array($matches) && $method == $this->request_method) {
		// Routes match and request method matches
		call_user_func_array($callable, $matches);
	}
}
{% endhighlight %}

Using `call_user_func_array()` allows us to invoke the `$callable` but also supplies it parameters: the values in `$matches`.

I hope this all makes sense, it's definitely a lot to take in. Make sure you peruse the full [source code][repo] to see how everything comes together. And as always, please feel free [reach out][contact] if you have any questions!

[semantic url]: http://en.wikipedia.org/wiki/Semantic_URL
[callable]: http://php.net/manual/en/language.types.callable.php
[dry]: https://en.wikipedia.org/wiki/Don%27t_repeat_yourself
[contact]: /contact
[repo]: https://github.com/smarulanda/Siesta
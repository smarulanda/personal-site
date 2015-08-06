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
	protected $http_methods = array('get', 'post', 'put', 'delete', 'patch');

	function __construct($base_path = '') {
		$this->base_path = $base_path;
		// Remove query string and trim trailing slash
		$this->request_uri = rtrim(strtok($_SERVER['REQUEST_URI'], '?'), '/');
		$this->request_method = $this->_determine_http_method();
	}

	private function _determine_http_method() {
		$method = strtolower($_SERVER['REQUEST_METHOD']);
		if (in_array($method, $this->http_methods)) {
			return $method;
		}
		return 'get';
	}
}
{% endhighlight %}

To be continued...

[semantic url]: http://en.wikipedia.org/wiki/Semantic_URL
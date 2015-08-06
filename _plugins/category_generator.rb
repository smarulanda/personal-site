module Jekyll

	class CategoryPageGenerator < Generator
		safe true

		def generate(site)
			site.categories.each_key do |category|
				site.pages << CategoryPage.new(site, site.source, File.join('category', category), category)
			end
		end
	end

	class CategoryPage < Page
		def initialize(site, base, dir, category)
			@site = site
			@base = base
			@dir = dir
			@name = 'index.html'

			self.process(@name)

			self.read_yaml(File.join(base, '_layouts'), 'posts.html')
			
			self.data['category'] = category
		end
	end

end
puppeteer	on March 16, 2016 at 4:04 pm
When I use run test got error “only generation of JSON objects or arrays allowed”

my class is,

~~~ puppet
class foo{
  file {'/tmp/test':
    ensure => present
  }
}
~~~
rspec-puppet test case

~~~ ruby
require spec_helper
describe 'foo' do
  it {
      File.write(
        'foo.json',
        JSON.pretty_generate(catalogue)
     )
  }
end
is there any issue with ruby version. I have
~~~

~~~ text
$/opt/puppet/bin/ruby -v
ruby 1.9.3p551 (2014-11-13 revision 48407) [x86_64-linux]
~~~

Alex Harvey	on March 16, 2016 at 5:00 pm
Interesting. By looking at this bug fix here turns out the object is in PSON format rather than JSON. I updated the post with this correction. Thanks!

puppeteer	on April 6, 2016 at 4:46 pm
Thanks, it worked.

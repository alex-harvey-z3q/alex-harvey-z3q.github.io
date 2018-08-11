Brad	on December 7, 2016 at 1:44 am
This has been a useful intro, many thanks.

One thing I still don’t understand is how you are including the class like so:

~~~ ruby
let(:manifest) {
<<-EOS
include spacewalk::server
EOS
}
~~~

I understand that the copy would create a directory on the target node called spacewalk and that inside it you presumably have a class called server? Would have been nice to see it as I am struggling to get beaker to find a test class right now.

Can you include the manifest file and maybe some comments on how beaker finds it?

Alex Harvey	on December 7, 2016 at 10:54 am
Thanks for your comments, Brad.

The ‘let manifest’ block results in a temporary file being created with one line ‘include spacewalk::server’. That temporary file is then applied via apply_manifest, which has the same effect as ‘puppet apply’.

The module is copied to the default module path as appropriate for the version of Puppet you told it to use. If that directory is ‘/etc/puppetlabs/code/modules’ then your module will appear in ‘/etc/puppetlabs/code/modules/spacewalk’ and you’ll have the server class in ‘/etc/puppetlabs/code/modules/spacewalk/manifests/server.pp’.

If your class is not being found, I guess it’s time to set $BEAKER_destroy to ‘no’ so that you can log in and debug this further.

Isaiah Frantz	on April 11, 2017 at 8:09 am
Some really good info, thanks!
Do you know how you wire hiera into beaker? I’ve searched high and low but haven’t seen anybody post anything about it 🙁
I’m currently on 4.2.2 so no in-module hiera, this beaker effort is in part to ensure my move to something 4.5+ will be smooth so I need to have tests succeed first.
Any help or links to get me going would be much appreciated.
Thank you!

Alex Harvey	on April 11, 2017 at 5:53 pm
No problem Isaiah.
Perhaps I should write a post to show people how to do that. The short answer is there are helpers in the hiera-beaker Gem, see https://github.com/puppetlabs/beaker-hiera/blob/master/lib/beaker-hiera/helpers.rb. Another option is the SIMP guys who wrote this https://github.com/simp/rubygem-simp-beaker-helpers.

Personally, I don’t think I would use Beaker to test your Hiera data. I normally do that kind of testing at the Puppet Control repo level using Rspec-puppet.

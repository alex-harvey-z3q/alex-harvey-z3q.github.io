Jerald Sheets	on March 14, 2017 at 2:12 am
It would appear your Rakefile is not a complete example. In article #2, you refer to contents of your Rakefile that you do not address in article #1 ( the :beaker and :beaker_nodes tasks). An example of those tasks for the Rakefile would be excellent to have.

Alex Harvey	on March 18, 2017 at 1:01 am
I had a look, and I realised that the wording in the article was incorrect, so I corrected it. The :beaker and :beaker_nodes tasks come from the Puppetlabs_spec_helper gem (see the code here https://github.com/puppetlabs/puppetlabs_spec_helper/blob/master/lib/puppetlabs_spec_helper/rake_tasks.rb#L38-L42 and here https://github.com/puppetlabs/puppetlabs_spec_helper/blob/master/lib/puppetlabs_spec_helper/rake_tasks.rb#L62-L70), and they have been refactored in a recent version, in this commit here:https://github.com/puppetlabs/puppetlabs_spec_helper/commit/3069965290ad79ed9fbdc185de311ae47172d61f

I don’t use them myself.

Hope that helps.

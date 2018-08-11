
Evil Del	on November 8, 2016 at 1:27 am
Hi, I get a json file, but it has no resources. The output says environment is ‘production’ when it should be ‘stress_test’.

~~~ text
$ sudo -u puppet /opt/puppetlabs/bin/puppet master –configprint vardir
/opt/puppetlabs/server/data/puppetserver/.puppetlabs/opt/puppet/cache
$ sudo -u puppet vim /opt/puppetlabs/server/data/puppetserver/.puppetlabs/opt/puppet/cache/yaml/facts/cp1steapp011.sg1.prod.yaml
~~~

# The fact file looks good.
Why an I getting no resources?

Alex Harvey	on November 10, 2016 at 6:03 pm
Well there are two obvious differences in what you’re trying to do and what I did – one is (as I mentioned), I was using Puppet 3. The other is that you’re calling sudo -u puppet. Could you tell me if not using sudo makes a difference?

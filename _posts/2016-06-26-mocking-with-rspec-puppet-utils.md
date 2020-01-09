---
layout: post
title: "Mocking with rspec-puppet-utils"
date: 2016-06-26
author: Alex Harvey
category: puppet
tags: puppet rspec
---

This post came out of a [question](https://ask.puppet.com/question/26542/using-razorsedgenetwork-with-hiera/) that I answered at ask.puppet.com.

I decided to write some Rspec-puppet tests for a class that used the razorsedge/network module, and along the way decided to mock some of the functions that are normally delivered by it.

It was an excuse to try out Tom Poulton‘s [rspec-puppet-utils](https://github.com/Accuity/rspec-puppet-utils) project.

In this post I’m going to show how to use Tom’s project to mock functions; how to mock the Hiera function; how to test template logic; and also how to validate Hiera data directly.

If you’d like to follow along, I have this code at Github [here](https://github.com/alexharv074/rspec-puppet-utils-example.git).

{:toc}

## The problem

In the example, the question that prompted me to set all this up involved use of the network::hiera interface of the razorsedge/network module.

So, we have the following class:

~~~ puppet
# manifests/init.pp

class profiles::network {
  include network::hiera
}
~~~

And Hiera data:

~~~ yaml
# spec/fixtures/hieradata/common.yaml

network::bond_static:
  bond0:
    ensure: up
    ipaddress : 10.0.0.10
    netmask: 255.255.255.0
    gateway: 10.0.0.254
    bonding_opts: 'mode=active-backup miimon=100'
network::bond_slave
  eth0:
    macaddress: 'XXXXXXXXXXXXX'
    ethtool_opts: 'autoneg off speed 1000 duplex full'
    master: 'bond0'
~~~

We would like to write tests to prove that the catalog contains appropriate resources.

## Setting up fake Hiera data

To begin with I set up the fake Hiera data as per normal:

~~~ yaml
# spec/fixtures/hiera/hiera.yaml

---
:backends:
  - yaml
:yaml:
  :datadir: spec/fixtures/hieradata
:hierarchy:
  - common
~~~

~~~ ruby
# spec/spec_helper.rb

require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |c|
  c.hiera_config = 'spec/fixtures/hiera/hiera.yaml'
end
~~~

And I write some tests:

~~~ ruby
# spec/classes/test_spec.rb

require 'spec_helper'

describe 'test' do
  it do
    is_expected.to contain_network__bond__static('bond0').with(
      'ensure'       => 'up',
      'ipaddress'    => '10.0.0.10',
      'netmask'      => '255.255.255.0',
      'gateway'      => '10.0.0.254',
      'bonding_opts' => 'mode=active-backup miimon=100',
    )
  end

  it do
    is_expected.to contain_network__bond__slave('eth0').with(
      'macaddress'   => 'XXXXXXXXXXXX',
      'ethtool_opts' => 'autoneg off speed 1000 duplex full',
      'master'       => 'bond0',
    )
  end
end
~~~

We run the tests and see the following failure:

~~~ text
$ bundle exec rake spec
...
     Puppet::PreformattedError:
       Evaluation Error: Error while evaluating a Resource Statement, Evaluation Error:
  Error while evaluating a Function Call, XXXXXXXXXXXX is not a MAC address. at ...
~~~

Now, a little further digging reveals that the is_mac_address function delivered by Stdlib is complaining that ‘XXXXXXXXXXXX’ isn’t really a MAC address.

Obviously, one way to solve this is by simply providing a valid fake MAC address in the test. We can’t do that here, because … well, ok, because I’m searching for an excuse to stub functions. Instead, we’re going to stub the is_mac_address function!

## Set up rspec-puppet-utils

### Update Gemfile

To Gemfile we add:

~~~ ruby
gem 'rspec-puppet-utils', :require => false
~~~

### Update the bundle

We update the bundle with:

~~~ text
$ bundle update
Update spec/spec_helper.rb
~~~

To our spec helper we add:

~~~ ruby
require 'rspec-puppet-utils'
~~~

### Stub out the function

Finally, the important bit, we actually update our tests to stub out the function.

~~~ ruby
# spec/classes/test_spec.rb

before(:each) {
  MockFunction.new('is_mac_address') { |f|
    f.stubs(:call).with(['XXXXXXXXXXXX']).returns(true)
  }
...
~~~

Be aware that the rspec-puppet-utils Gem is using Mocha, not Rspec-mocks, so we don’t have the familiar Rspec 3 syntax – we have “stubs” instead of “allow” and so on.

### Run the tests again

Running the tests again and we get:

~~~ text
$ bundle exec rake spec
...
Finished in 1.04 seconds (files took 1.01 seconds to load)
2 examples, 0 failures
~~~

## Testing with the Hiera validator

Another interesting feature of rspec-puppet-utils is the Hiera Validator. We can use this to write tests to test individual items of Hiera data from our hierarchy.

We add the following code:

~~~ ruby
describe 'YAML hieradata' do

  validator = HieraData::YamlValidator.new('spec/fixtures/hieradata')
  validator.load_data :ignore_empty

  validator.validate('network::bond_static') { |v|
    it {
      expect(v).to be_a Hash
    }

    ['netmask', 'ipaddress', 'gateway'].each do |k|
      it {
        expect(v['bond0'][k]).to match /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/
      }
    end
  }

  validator.validate('network::bond_slave') { |v|
    it {
      expect(v).to be_a Hash
    }
    it {
      expect(v['eth0']['macaddress']).to eq 'XXXXXXXXXXXX'
    }
  }
end
~~~

It’s fairly self-explanatory. We write expectations that the Hiera data keys network::bond_slave and network::bond_static will exist and be Hashes. And just for fun, I expect the netmask, ipaddress and gateway to match `^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$` (which, obviously, is an IP address regexp). And finally, I expect our MAC address to be exactly equal to XXXXXXXXXXXX.

## Mocking the Hiera function itself

Ok, well Mocking the Hiera function itself is done just the same way as mocking any other function:

~~~ ruby
before(:each) {
  MockFunction.new('hiera') { |f|
    f.stubbed.with('network::bond_static').returns(
      'bond0' => {
        'ensure'    => 'up',
        'ipaddress' => '10.0.0.10',
        'netmask'   => '255.255.255.0',
        'gateway'   => '10.0.0.254',
        'bonding_opts' => 'mode=active-backup miimon=100',
      },
    )
    f.stubbed.with('network::bond_slave').returns(
      'eth0' => {
        'macaddress'   => 'XXXXXXXXXXXX',
        'ethtool_opts' => 'autoneg off speed 1000 duplex full',
        'master'       => 'bond0',
      },
    )
  }
}
~~~

One big problem with this however. We don’t use the Hiera function in our code; we rely on the automatic parameter lookup feature! As of right now, I haven’t figured out what to do about this.

## Template harness

The rspec-puppet-utils also provides a Template testing harness, that allows us to directly test the output of an ERB template, given input facts and variables.

In the present example, I don’t have any templates in my module-under-test – however we call the razorsedge/network module, which does have templates.

So the tests for these templates rightly belong in the razorsedge/network project, but for the sake of a demonstration, I’m going to test them anyway.

We add some Ruby code as follows:

~~~ ruby
describe 'ifcfg-eth.erb' do

  let(:scope) { PuppetlabsSpec::PuppetInternals.scope }

  it do
    harness = TemplateHarness.
      new('spec/fixtures/modules/network/templates/ifcfg-eth.erb', scope)
    harness.set('@interface', 'bond0')
    harness.set('@ipaddress', '10.0.0.10')
    harness.set('@netmask', '255.255.255.0')
    harness.set('@gateway', '10.0.0.254')
    harness.set('@bonding_opts', 'mode=active-backup miimon=100')
    harness.set('@bootproto', 'none')
    harness.set('@onboot', 'yes')
    harness.set('@hotplug', 'no')
    harness.set('@scope', false)

    result = harness.run
    expect(result).to eq 'DEVICE=bond0
BOOTPROTO=none
ONBOOT=yes
HOTPLUG=yes
TYPE=Ethernet
IPADDR=10.0.0.10
NETMASK=255.255.255.0
GATEWAY=10.0.0.254
BONDING_OPTS="mode=active-backup miimon=100"
PEERDNS=no
NM_CONTROLLED=no
'
  end
end
~~~

The part about this that is hacky is that I’m finding the template itself at spec/fixtures/modules/network/templates/ifcfg-eth.erb. What’s it doing there? Well, it gets checked out by the Puppetlabs_spec_helper, as it processes my .fixtures.yml. All dependent modules end up in spec/fixtures/modules, and I expect anyone who has read this far already knows this.

In case you’re wondering how I deduced the expected content of the output template line by line, well I cheated and [looked](https://alexharv074.github.io/2016/03/13/dumping-the-catalog-in-rspec-puppet.html) inside a catalog I compiled!

The harness.set lines allow me to set the values of the class variables expected by the ERB template.

And that’s it for rspec-puppet-utils.

## Conclusion

So in summary I’ve played with Tom Poulton’s excellent project rspec-puppet-utils. I’ve shown how to stub functions; how to validate Hiera data; and how to test ERB templates. I was very happy to find that everything worked just as documented, and figuring all of this out wasn’t painful at all.

Thanks again to Tom Poulton for this very useful tool.

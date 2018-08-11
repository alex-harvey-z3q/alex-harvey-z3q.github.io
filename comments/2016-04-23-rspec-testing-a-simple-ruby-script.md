dade	on June 1, 2017 at 5:46 pm
Hi, Alex! Great post!

When you test #process method you write unit-test and straight say about this.

Why you write integration tests when you test #get_data? Why just not to write:

~~~ ruby
describe '#get_data' do
  it 'should read YAML-formatted data from a file' do
    allow(YAML).to receive(:load_file).with('/some/file').and_return({'times' => ['10h 3m', '2h 5m', '40m']})
    expect(get_data('/some/file').to eq({'times' => ['10h 3m', '2h 5m', '40m']}) 
  end
 
  it 'should error out if YAML is badly formatted' do
    allow(YAML).to receive(:load_file).with('/some/file').and_raise(RuntimeError)
    expect { get_data('/some/file') }.to raise_error(RuntimeError, /Error reading \'//some//file\'/)
  end
end
~~~
Alex Harvey	on June 1, 2017 at 6:18 pm
I suppose you could do that. But why would I modify the behaviour of the YAML class if there is no need to?

dade	on June 1, 2017 at 7:23 pm
In this article https://robots.thoughtbot.com/back-to-basics-writing-unit-tests-first they stub class File, make unit-test(they don’t want to create a new file every time).
I try to find a way of using integration and unit tests. When to use integration-tests and when unit-tests? Should I use both of them in on spec file? Or Should I create directories for spec/unit-tests and spec/integration-tests?
Your answer is very important for me, thanks

Alex Harvey	on June 2, 2017 at 2:25 pm
If you take a step back, you need to be focused on what the point of testing is; the point is to prove that your code is 100% correct. The amount and the type of testing you do depends on what you have written. In my script here, I don’t need integration testing because it is too simple. Most of the time, you will also want to write some integration tests. In general, you probably will end up with more tests for individual methods (unit tests) than you will for tests that test the interaction between classes (integration tests). Putting the tests in spec/unit and spec/integration seems to make sense to me.

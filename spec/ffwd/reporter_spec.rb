require 'ffwd/reporter'

describe FFWD::Lifecycle do
  # TODO: stub, please expand.

  class Foo
    include FFWD::Reporter
  end

  f = Foo.new
  f.increment :total
end

require 'ffwd/reporter'

describe FFWD::Lifecycle do
  # TODO: stub, please expand.

  class Foo
    include FFWD::Reporter

    report_key :foo
  end

  f = Foo.new
  f.increment :foo
end

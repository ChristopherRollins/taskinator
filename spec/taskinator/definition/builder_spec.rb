require 'spec_helper'

describe Taskinator::Definition::Builder do

  let(:definition) do
    Module.new() do
      extend Taskinator::Definition

      def iterator_method(*); end
      def task_method(*); end
    end
  end

  let(:process) {
    Class.new(Taskinator::Process).new(definition)
  }

  let(:args) { [:arg1, :arg2, {:option => 1, :another => false}] }

  let(:block) { SpecSupport::Block.new() }

  let(:define_block) {
    the_block = block
    Proc.new {|*args| the_block.call }
  }

  subject { Taskinator::Definition::Builder.new(process, definition, *args) }

  it "assign attributes" do
    expect(subject.process).to eq(process)
    expect(subject.definition).to eq(definition)
    expect(subject.args).to eq(args)
    expect(subject.options).to eq({:option => 1, :another => false})
  end

  describe "#option?" do
    it "invokes supplied block for 'option' option" do
      expect(block).to receive(:call)
      subject.option?(:option, &define_block)
    end

    it "does not invoke supplied block for 'another' option" do
      expect(block).to_not receive(:call)
      subject.option?(:another, &define_block)
    end

    it "does not invoke supplied block for an unspecified option" do
      expect(block).to_not receive(:call)
      subject.option?(:unspecified, &define_block)
    end
  end

  describe "#sequential" do
    it "invokes supplied block" do
      expect(block).to receive(:call)
      subject.sequential(&define_block)
    end

    it "creates a sequential process" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_sequential_process_for).with(definition, {}).and_call_original
      subject.sequential(&define_block)
    end

    it "fails if block isn't given" do
      expect {
        subject.sequential()
      }.to raise_error(ArgumentError)
    end
  end

  describe "#concurrent" do
    it "invokes supplied block" do
      expect(block).to receive(:call)
      subject.concurrent(&define_block)
    end

    it "creates a concurrent process" do
      allow(block).to receive(:call)
      expect(Taskinator::Process).to receive(:define_concurrent_process_for).with(definition, Taskinator::CompleteOn::First, {}).and_call_original
      subject.concurrent(Taskinator::CompleteOn::First, &define_block)
    end

    it "fails if block isn't given" do
      expect {
        subject.concurrent()
      }.to raise_error(ArgumentError)
    end
  end

  describe "#for_each" do
    it "creates tasks for each returned item" do
      # the definition is mixed into the eigen class of Executor
      # HACK: replace the internal executor instance

      executor = Taskinator::Executor.new(definition)

      subject.instance_eval do
        @executor = executor
      end

      expect(executor).to receive(:iterator_method) do |*args, &block|
        3.times(&block)
      end

      expect(block).to receive(:call).exactly(3).times

      subject.for_each(:iterator_method, &define_block)
    end

    it "fails if iterator method is nil" do
      expect {
        subject.for_each(nil, &define_block)
      }.to raise_error(ArgumentError)
    end

    it "fails if iterator method is not defined" do
      expect {
        subject.for_each(:undefined_iterator, &define_block)
      }.to raise_error(NoMethodError)
    end

    it "fails if block isn't given" do
      expect {
        subject.for_each(nil)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#task" do
    it "creates a task" do
      expect(Taskinator::Task).to receive(:define_step_task).with(process, :task_method, args, {})
      subject.task(:task_method)
    end

    it "fails if task method is nil" do
      expect {
        subject.task(nil)
      }.to raise_error(ArgumentError)
    end

    it "fails if task method is not defined" do
      expect {
        subject.task(:undefined)
      }.to raise_error(NoMethodError)
    end
  end

  describe "#job" do
    it "creates a job" do
      job = double('job', :perform => true)
      expect(Taskinator::Task).to receive(:define_job_task).with(process, job, args, {})
      subject.job(job)
    end

    it "fails if job module is nil" do
      expect {
        subject.job(nil)
      }.to raise_error(ArgumentError)
    end

    # ok, fuzzy logic to determine what is ia job here!
    it "fails if job module is not a job" do
      expect {
        subject.job(double('job', :methods => [], :instance_methods => []))
      }.to raise_error(ArgumentError)
    end
  end

  describe "#sub_process" do
    let(:sub_definition) do
      Module.new() do
        extend Taskinator::Definition

        define_process :some_arg1, :some_arg2, :some_arg3 do
        end
      end
    end

    it "creates a sub process" do
      expect(sub_definition).to receive(:create_process).with(*args).and_call_original
      subject.sub_process(sub_definition)
    end

    it "creates a sub process task" do
      sub_process = sub_definition.create_process(:argX, :argY, :argZ)
      allow(sub_definition).to receive(:create_process) { sub_process }
      expect(Taskinator::Task).to receive(:define_sub_process_task).with(process, sub_process, {})
      subject.sub_process(sub_definition)
    end
  end

end

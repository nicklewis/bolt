# frozen_string_literal: true

require 'logging'
require 'bolt/result'
require 'bolt/shell'

module Bolt
  module Transport
    # This class provides the default behavior for Transports. A Transport is
    # responsible for uploading files and running commands, scripts, and tasks
    # on Targets.
    #
    # Bolt executes work on the Transport in "batches". To do that, it calls
    # the batches() method, which is responsible for dividing the list of
    # Targets into batches according to how it wants to handle them. It will
    # then call Transport#batch_task, or the corresponding method for another
    # operation, passing a list of Targets. The Transport returns a list of
    # Bolt::Result objects, one per Target. Each batch is executed on a
    # separate thread, controlled by the `concurrency` setting, so many batches
    # may be running in parallel.
    #
    # The default batch implementation splits the list of Targets into batches
    # of 1. It then calls run_task(), or a corresponding method for other
    # operations, passing in the single Target.
    #
    # Most Transport implementations, like the SSH and WinRM transports, don't
    # need to do their own batching, since they only operate on a single Target
    # at a time. Those Transports can implement the run_task() and related
    # methods, which will automatically handle running many Targets in
    # parallel, and will handle publishing start and finish events for each
    # Target.
    #
    # Transports that need their own batching, like the Orch transport, can
    # instead override the batches() method to split Targets into sets that can
    # be executed together, and override the batch_task() and related methods
    # to execute a batch of nodes. In that case, those Transports should accept
    # a block argument and call it with a :node_start event for each Target
    # before executing, and a :node_result event for each Target after
    # execution.
    class Base
      attr_reader :logger

      def initialize
        @logger = Logging.logger[self]
      end

      def with_events(target, callback)
        callback&.call(type: :node_start, target: target)

        result = begin
                   yield
                 rescue StandardError, NotImplementedError => e
                   Bolt::Result.from_exception(target, e)
                 end

        callback&.call(type: :node_result, result: result)
        result
      end

      # Raises an error if more than one target was given in the batch.
      #
      # The default implementations of batch_* strictly assume the transport is
      # using the default batch size of 1. This method ensures that is the
      # case and raises an error if it's not.
      def assert_batch_size_one(method, targets)
        if targets.length > 1
          message = "#{self.class.name} must implement #{method} to support batches (got #{targets.length} nodes)"
          raise NotImplementedError, message
        end
      end

      # Runs the given task on a batch of nodes.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_task(targets, task, arguments, options = {}, &callback)
        assert_batch_size_one("batch_task()", targets)
        target = targets.first
        with_events(target, callback) do
          @logger.debug { "Running task run '#{task}' on #{target.safe_name}" }
          run_task(target, task, arguments, options)
        end
      end

      # Runs the given command on a batch of nodes.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_command(targets, command, options = {}, &callback)
        assert_batch_size_one("batch_command()", targets)
        target = targets.first
        with_events(target, callback) do
          @logger.debug("Running command '#{command}' on #{target.safe_name}")
          run_command(target, command, options)
        end
      end

      # Runs the given script on a batch of nodes.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_script(targets, script, arguments, options = {}, &callback)
        assert_batch_size_one("batch_script()", targets)
        target = targets.first
        with_events(target, callback) do
          @logger.debug { "Running script '#{script}' on #{target.safe_name}" }
          run_script(target, script, arguments, options)
        end
      end

      # Uploads the given source file to the destination location on a batch of nodes.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_upload(targets, source, destination, options = {}, &callback)
        assert_batch_size_one("batch_upload()", targets)
        target = targets.first
        with_events(target, callback) do
          @logger.debug { "Uploading: '#{source}' to #{destination} on #{target.safe_name}" }
          upload(target, source, destination, options)
        end
      end

      def batch_connected?(targets)
        assert_batch_size_one("connected?()", targets)
        connected?(targets.first)
      end

      # Split the given list of targets into a list of batches. The default
      # implementation returns single-node batches.
      #
      # Transports may override this method, and the corresponding batch_*
      # methods, to implement their own batch processing.
      def batches(targets)
        targets.map { |target| [target] }
      end

      # Transports should override this method with their own implementation of running a command.
      def run_command(*_args)
        raise NotImplementedError, "run_command() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of running a script.
      def run_script(*_args)
        raise NotImplementedError, "run_script() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of running a task.
      def run_task(*_args)
        raise NotImplementedError, "run_task() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of file upload.
      def upload(*_args)
        raise NotImplementedError, "upload() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of a connection test.
      def connected?(_targets)
        raise NotImplementedError, "connected?() must be implemented by the transport class"
      end
    end
  end
end

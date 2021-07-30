module Searchkick
  class RecordIndexer
    attr_reader :record, :index

    def initialize(record)
      @record = record
      @index = record.class.searchkick_index
    end

    def reindex(method_name = nil, refresh: false, mode: nil, after_reindex_params: nil)
      unless [:inline, true, nil, :async, :queue].include?(mode)
        raise ArgumentError, "Invalid value for mode"
      end

      mode ||= Searchkick.callbacks_value || index.options[:callbacks] || true
      mode = record.instance_exec(&mode) if mode.is_a?(Proc)

      case mode
      when :queue
        if method_name
          raise Searchkick::Error, "Partial reindex not supported with queue option"
        end

        # always pass routing in case record is deleted
        # before the queue job runs
        if record.respond_to?(:search_routing)
          routing = record.search_routing
        end

        # escape pipe with double pipe
        value = queue_escape(record.id.to_s)
        value = "#{value}|#{queue_escape(routing)}" if routing
        index.reindex_queue.push(value)
      when :async
        unless defined?(ActiveJob)
          raise Searchkick::Error, "Active Job not found"
        end

        # always pass routing in case record is deleted
        # before the async job runs
        if record.respond_to?(:search_routing)
          routing = record.search_routing
        end

        Searchkick::ReindexV2Job.perform_later(
          record.class.name,
          record.id.to_s,
          method_name ? method_name.to_s : nil,
          routing: routing,
          after_reindex_params: after_reindex_params
        )
      else # bulk, inline/true/nil
        Searchkick::ThreadSafeIndexer.new.reindex_stale_record(record, method_name, after_reindex_params: after_reindex_params)
        index.refresh if refresh
      end
    end

    private

    def queue_escape(value)
      value.gsub("|", "||")
    end
  end
end

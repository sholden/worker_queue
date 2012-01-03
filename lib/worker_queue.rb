require "worker_queue/version"
require 'worker_queue/worker_queue_item'
require 'worker_queue/worker_queue_item_loader'

module WorkerQueue
  require 'worker_queue/railtie' if defined?(Rails)
end

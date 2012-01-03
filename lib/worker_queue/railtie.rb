require 'worker_queue'

module WorkerQueue
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "worker_queue/tasks/worker_queue.rake"
    end
  end
end
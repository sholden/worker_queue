require 'worker_queue'

module WorkerQueue
  class Railtie < ::Rails::Railtie
    railtie_name :worker_queue
    
    rake_tasks do
      require 'tasks/worker_queue.tasks'
    end
  end
end
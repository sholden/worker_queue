namespace :worker_queue do
  desc 'Load worker items'
  task :load => :environment do
    WorkerQueue.load
  end

  desc 'Load worker items and start the worker'
  task :load_and_work => [ :load, :work ] do
  
  end

  desc 'Start the worker'
  task :work => :environment do
    WorkerQueue.work if WorkerQueue.work?
  end
end
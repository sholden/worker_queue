require 'digest/sha1'
module WorkerQueue
  class WorkerQueueItem < ActiveRecord::Base
    before_create :assign_task_group
    
    # Status messages
    STATUS_WAITING    = 0
    STATUS_RUNNING    = 1
    STATUS_ERROR      = 2
    STATUS_COMPLETED  = 3
    STATUS_SKIPPED    = 4 

    scope :waiting,   lambda { where(:status => 0) } # STATUS_WAITING
    scope :running,   lambda { where(:status => 1) } # STATUS_RUNNING
    scope :errors,    lambda { where(:status => 2) } # STATUS_ERROR
    scope :completed, lambda { where(:status => 3) } # STATUS_COMPLETED
    scope :skipped,   lambda { where(:status => 4) } # STATUS_SKIPPED
    scope :busy,      lambda { where(['status = ? OR status = ?', 1, 2]) } # STATUS_RUNNING STATUS_ERROR
    scope :with_run_at, lambda { |time| where("(run_at is NULL) or (? >= run_at)", time) }
     
    validate :hash_in_argument_hash  
    serialize :argument_hash, Hash
    
    ##if no task group...create random one

    def assign_task_group
      unless self.task_group
        self.task_group = Digest::SHA1.hexdigest(Time.now.to_f.to_s)
      end
    end
    def self.error_range(first_id,second_id)
      WorkerQueue::WorkerQueueItem.where("id >= ? and id <= ? and error_message is not NULL", first_id, second_id).each {|item|
        puts "item : #{item.id} error_message : #{item.error_message}"
      }
    end
    # Execute ourselves
    # Note that the task executed expects Class.method(args_hash) to return true or false.
    # Options
    # *<tt>:keep_data</tt> Do not empty the data on completion.
    def execute(options = {})
      ah = argument_hash.clone
      ah.store(:data, data) if data
      begin
        unless Kernel.const_get(class_name.to_sym).send(method_name.to_sym, ah) #class_name.classify.constantize.send(method_name.to_sym, ah)
          self.status = STATUS_ERROR
          self.error_message = "called method returned false"
        end
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
        self.status = STATUS_ERROR
        self.error_message = "class or method does not exist : " + e.to_s 
        self.error_backtrace = e.backtrace.join("\n")
      end
      
      # If we have an error, do not run anything in this group (halt the chain)
      if error?
        self.status   = STATUS_SKIPPED if skip_on_error
      else
        self.status   = STATUS_COMPLETED
        self.data     = nil unless !!options[:keep_data]
      end
    end
    
    # Check if this task is running
    def running?
      self.status == STATUS_RUNNING
    end
    
    # Check if the task is completed
    def completed?
      self.status == STATUS_COMPLETED
    end
    
    def error?
      self.status == STATUS_ERROR
    end
    
    # Check if we can execute ourselves
    def executable?
      
      # Return false if picked up by another WQ instance
      if id
        old_lock_version = lock_version
        self.reload
        return false if old_lock_version != lock_version
      end
      
      # Return true we can sill be executed
      return WorkerQueue.available_tasks.include?(self) && !completed? && !running?    
    end

    # Validates hash in the argument_hash attribute. If none found, a hash is inserted.
    def hash_in_argument_hash
      argument_hash = {} if argument_hash.nil?
      return true
    end
    
    # Class methods
    
    # This prevents us fetching the data field for a simple status lookup
    def self.partial_select_attributes
      (columns.collect{|x| x.name} - ['data']).join(',')
  end

    # Find tasks with a certain flag uncompleted tasks in the database
    def self.waiting_tasks
      waiting.with_run_at(Time.zone.now).find(:all, :order => 'id', :select => partial_select_attributes)
    end

    # Find all tasks being worked on at the moment.
    def self.busy_tasks
      busy(:order => 'id', :select => partial_select_attributes)
    end

    def self.push(class_name, method_name, task_name, argument_hash={}, skip_on_error=false, run_at=Time.now )

      wq                  = WorkerQueue::WorkerQueueItem.new
      wq.class_name       = class_name
      wq.method_name      = method_name
      wq.task_name        = task_name
      wq.argument_hash    = argument_hash
      wq.skip_on_error    = skip_on_error
      wq.run_at = run_at
      wq.save!
    end

  end
end

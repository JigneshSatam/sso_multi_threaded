class ThreadSafetyController < ApplicationController
  @@lock = Mutex.new
  # def initialize
  #   # debugger
  #   # @name,@checking,@savings = name,checking,savings
  #   @@lock = Mutex.new  # For thread safety
  # end
  # def initialize
  # end
  $gloabal_variable = 0
  @@class_variable = 0
  @instance_variable_at_class_level = 0
  def index
  end

  def simple
    # debugger
    @@sleep_time = params[:sleep].to_i
    Thread.current[:name] = "sleep time #{params[:sleep]} thread :"
    puts "&&&&&&&&&&&&& #{Thread.current[:name]} ===> Started &&&&&&&&&&&&&&&"
    @@lock.synchronize {
      puts "&&&&&&&&&&&&& #{Thread.current[:name]} ===> #{@@sleep_time} in lock before sleep &&&&&&&&&&&&&&&"
      sleep(@@sleep_time)
      @@sleep_time += 1
      puts "&&&&&&&&&&&&& #{Thread.current[:name]} ===> #{@@sleep_time} in lock after sleep &&&&&&&&&&&&&&&"
    }
    # sleep(@@sleep_time)
    puts "&&&&&&&&&&&&& #{Thread.current[:name]} ===> #{@@sleep_time} out lock &&&&&&&&&&&&&&&"

    @instance_variable_at_method_level ||= 0
    @instance_variable_at_class_level ||= 0

    $gloabal_variable += 1
    @@class_variable += 1
    @instance_variable_at_class_level += 1
    @instance_variable_at_method_level += 1

    puts "IN SIMPLE method #{Time.now}"
    # render :text => "gloabal_variable ==> #{$gloabal_variable}\n"
    render :text => "class_variable ==> #{@@class_variable}\n"
    # render :text => "instance_variable_at_class_level ==> #{@instance_variable_at_class_level}\n"
    # render :text => "instance_variable_at_method_level ==> #{@instance_variable_at_method_level}\n"
    # render :text => "class_variable ==> #{@@class_variable} || instance_variable_at_class_level ==> #{@instance_variable_at_class_level} || instance_variable_at_method_level ==> #{@instance_variable_at_method_level}"

    # render :text => "Welcaome to simple method\n"
  end

  def infinite
    while true
      puts "IN infinite"
    end
  end
end

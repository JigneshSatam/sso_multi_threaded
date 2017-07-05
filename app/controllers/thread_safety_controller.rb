class ThreadSafetyController < ApplicationController
  $gloabal_variable = 0
  @@class_variable = 0
  @instance_variable_at_class_level = 0
  def index
  end

  def simple
    @instance_variable_at_method_level ||= 0
    @instance_variable_at_class_level ||= 0

    $gloabal_variable += 1
    @@class_variable += 1
    @instance_variable_at_class_level += 1
    @instance_variable_at_method_level += 1

    puts "IN SIMPLE method #{Time.now}"
    # sleep(1)
    # render :text => "gloabal_variable ==> #{$gloabal_variable}\n"
    # render :text => "class_variable ==> #{@@class_variable}\n"
    # render :text => "instance_variable_at_class_level ==> #{@instance_variable_at_class_level}\n"
    # render :text => "instance_variable_at_method_level ==> #{@instance_variable_at_method_level}\n"
    # render :text => "class_variable ==> #{@@class_variable} || instance_variable_at_class_level ==> #{@instance_variable_at_class_level} || instance_variable_at_method_level ==> #{@instance_variable_at_method_level}"

    render :text => "Welcaome to simple method\n"
  end

  def infinite
    while true
      puts "IN infinite"
    end
  end
end

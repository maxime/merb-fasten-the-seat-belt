# make sure we're running inside Merb
if defined?(Merb::Plugins)

  # Merb gives you a Merb::Plugins.config hash...feel free to put your stuff in your piece of it
  #Merb::Plugins.config[:merb_fasten_the_seat_belt] = {
  #  :chickens => false
  #}
  
  Merb::BootLoader.before_app_loads do
    # require code that must be loaded before the application
    require File.join(File.dirname(__FILE__), 'fasten-the-seat-belt')
    
    DataMapper::Base.send(:include, FastenTheSeatBelt)
  end
  
  #Merb::BootLoader.after_app_loads do
    # code that can be required after the application loads
  #end
  
  # Merb::Plugins.add_rakefiles "merb-fasten-the-seat-belt/merbtasks"
end
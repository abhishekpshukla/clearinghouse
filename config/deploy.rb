# Bundler and RVM integrations
require 'bundler/capistrano'
require "rvm/capistrano"

set :stages, %w(staging)
require 'capistrano/ext/multistage'

set :application, "Clearinghouse"
set :repository,  "http://github.com/rideconnection/clearinghouse.git"
set :deploy_to, "/home/deployer/rails/clearinghouse"

set :scm, :git
set :deploy_via, :remote_cache

set :user, "deployer"  # The server's user for deployments
set :use_sudo, false

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

task :link_database_yml do
  puts "    Link in database.yml file"
  run  "ln -nfs #{deploy_to}/shared/config/database.yml #{deploy_to}/current/config/database.yml"
  puts "    Link in app_config.yml file"
  run  "ln -nfs #{deploy_to}/shared/config/app_config.yml #{deploy_to}/current/config/app_config.yml"
end

after "deploy:create_symlink", :link_database_yml
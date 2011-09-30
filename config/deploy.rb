set :stages, %w(production development)
require 'capistrano/ext/multistage'

#$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
#require "rvm/capistrano"

#set :rvm_ruby_string, '1.9.2@swag52'
#set :rvm_bin_path, '/usr/local/rvm/bin'

require 'bundler/capistrano'
# Must be set for the password prompt from git to work

ssh_options[:forward_agent] = true

default_run_options[:pty] = true

set :application, "instiki"
set :scm, :git
set :repository,  "git@github.com:Scrimmage/instiki.git"
set :use_sudo,  false

set :deploy_via, :remote_cache
set :user, 'deployer'

set :domain, "docs.wescrimmage.com"
role :app, domain
role :web, domain
role :db,  domain, :primary => true
role :scm, domain

after "deploy:update_code", "deploy:update_shared_symlinks"
after "deploy:update_shared_symlinks", "deploy:migrate"

#ssh_options[:keys] = %w(/Users/caseyhelbling/.ssh/id_rsa /Users/kjell/.ssh/id_dsa)

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
    
    task :update_shared_symlinks do
      # individual files
      %w(config/database.yml).each do |path|
        run "rm -rf #{File.join(release_path, path)}"
        run "ln -fns #{File.join(deploy_to, "shared", path)} #{File.join(release_path, path)}"
      end
    end
    
  namespace :web do
    desc <<-DESC
      Present a maintenance page to visitors. Disables your application's web \
      interface by writing a "maintenance.html" file to each web server. The \
      servers must be configured to detect the presence of this file, and if \
      it is present, always display it instead of performing the request.

      By default, the maintenance page will just say the site is down for \
      "maintenance", and will be back "shortly", but you can customize the \
      page by specifying the REASON and UNTIL environment variables:

        $ cap deploy:web:disable \\
              REASON="a hardware upgrade" \\
              UNTIL="12pm Central Time"

      Further customization will require that you write your own task.
    DESC
    task :disable, :roles => :web do
      require 'erb'
      on_rollback { run "rm #{shared_path}/system/maintenance.html" }

      reason = ENV['REASON']
      deadline = ENV['UNTIL']      
      template = File.read('app/views/admins/maintenance.html.erb')
      page = ERB.new(template).result(binding)

      put page, "#{shared_path}/system/maintenance.html", :mode => 0644
    end
  end
end
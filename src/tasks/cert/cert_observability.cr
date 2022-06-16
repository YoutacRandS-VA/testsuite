# coding: utf-8
require "sam"
require "file_utils"
require "colorize"
require "totem"
require "../utils/utils.cr"

desc "In order to maintain, debug, and have insight into a protected environment, its infrastructure elements must have the property of being observable. This means these elements must externalize their internal states in some way that lends itself to metrics, tracing, and logging."
task "cert_observability", ["cert_observability_title", "log_output", "prometheus_traffic", "open_metrics", "routed_logs", "tracing"] do |_, args|
# task "cert_observability", ["cert_observability_title", "prometheus_traffic", "open_metrics", "routed_logs", "tracing"] do |_, args|
  # stdout_score("observability", "Observability and Diagnostics")
  stdout_score(["observability", "cert"], "Observability and Diagnostics")
  case "#{ARGV.join(" ")}" 
  when /cert_observability/
    stdout_info "Results have been saved to #{CNFManager::Points::Results.file}".colorize(:green)
  end
end

task "cert_observability_title" do |_, args|
  puts "Observability and Diagnostics Tests".colorize(Colorize::ColorRGB.new(0, 255, 255))
end


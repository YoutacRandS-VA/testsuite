#TODO Update Test
# require "../spec_helper"
# require "../../src/tasks/utils/utils.cr"
# require "colorize"

# describe CnfTestSuite do
#   before_all do
#     `./cnf-testsuite setup`
#     $?.success?.should be_true
#   end

#   after_all do
#     `./cnf-testsuite samples_cleanup`
#     $?.success?.should be_true
#   end

#   it "'testsuite all' should run all the microservice tests", tags: ["testsuite-microservice"] do
#     `./cnf-testsuite samples_cleanup`
#     response_s = `./cnf-testsuite all ~disk_fill ~pod_delete ~pod_network_latency ~pod_network_corruption ~pod_network_duplication ~pod_io_stress ~pod_memory_hog ~node_drain ~pod_dns_error ~chaos_network_loss ~chaos_cpu_hog ~chaos_container_kill ~platform ~volume_hostpath_not_found ~privileged ~increase_capacity ~decrease_capacity ~ip_addresses ~liveness ~readiness ~rolling_update ~rolling_downgrade ~rolling_version_change ~nodeport_not_used ~hostport_not_used ~hardcoded_ip_addresses_in_k8s_runtime_configuration ~helm_chart_valid ~helm_chart_published ~rollback ~secrets_used ~immutable_configmap "cnf-config=./sample-cnfs/sample-coredns-cnf/cnf-testsuite.yml" verbose`
#     LOGGING.info response_s
#     (/Final workload score:/ =~ response_s).should_not be_nil
#     (/Final score:/ =~ response_s).should_not be_nil
#     (CNFManager::Points.all_result_test_names(CNFManager::Points.final_cnf_results_yml).sort).should eq(["reasonable_startup_time", "reasonable_image_size"].sort)
#     (/^.*\.cr:[0-9].*/ =~ response_s).should be_nil
#     $?.success?.should be_true
#   end
# end

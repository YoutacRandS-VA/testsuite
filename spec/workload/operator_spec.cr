require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/utils/mysql.cr"
require "kubectl_client"
require "helm"
require "file_utils"
require "sam"
require "json"

OPERATOR_JSON_FILE = "operator.json"
MANAGER_JSON_FILE = "manager.json"

describe "Operator" do

  describe "pre OLM install" do
    it "'operator_test' operator should not be found", tags: ["operator_test"] do
      begin
        LOGGING.info `./cnf-testsuite cnf_setup cnf-path=sample-cnfs/sample_coredns`
        $?.success?.should be_true
        resp = `./cnf-testsuite -l info operator_installed`
        Log.info { "#{resp}" }
        (/NA: No Operators Found/ =~ resp).should_not be_nil
      ensure
        LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=sample-cnfs/sample_coredns`
        $?.success?.should be_true
      end
    end
  end

  describe "post OLM install" do
    install_dir = "#{tools_path}/olm"

    before_all do
      # Install OLM
      if Dir.exists?("#{install_dir}/olm/.git")
        Log.info { "OLM already installed. Skipping git clone for OLM." }
      else
        GitClient.clone("https://github.com/operator-framework/operator-lifecycle-manager.git #{install_dir}")
        `cd #{install_dir} && git fetch -a && git checkout tags/v0.22.0 && cd -`
      end

      Helm.install("operator --set olm.image.ref=quay.io/operator-framework/olm:v0.22.0 --set catalog.image.ref=quay.io/operator-framework/olm:v0.22.0 --set package.image.ref=quay.io/operator-framework/olm:v0.22.0 #{install_dir}/deploy/chart/")
    end

    after_all do
      # uninstall OLM
      pods = KubectlClient::Get.pods_by_resource(KubectlClient::Get.deployment("catalog-operator", "operator-lifecycle-manager"), "operator-lifecycle-manager") + KubectlClient::Get.pods_by_resource(KubectlClient::Get.deployment("olm-operator", "operator-lifecycle-manager"), "operator-lifecycle-manager") + KubectlClient::Get.pods_by_resource(KubectlClient::Get.deployment("packageserver", "operator-lifecycle-manager"), "operator-lifecycle-manager")

      Helm.uninstall("operator")
      # TODO: get the correct operator version from whatever file or api so we can delete it properly
      # will require updating KubectlClient::Get to support custom resources
      KubectlClient::Delete.command("csv prometheusoperator.0.47.0")

      pods.map do |pod|
        pod_name = pod.dig("metadata", "name")
        pod_namespace = pod.dig("metadata", "namespace")
        Log.info { "Wait for Uninstall on Pod Name: #{pod_name}, Namespace: #{pod_namespace}" }
        KubectlClient::Get.resource_wait_for_uninstall("Pod", "#{pod_name}", 180, "operator-lifecycle-manager")
      end

      second_count = 0
      wait_count = 20
      delete = false
      until delete || second_count > wait_count.to_i
        File.write(OPERATOR_JSON_FILE, "#{KubectlClient::Get.namespaces("operators").to_json}")
        json = File.open(OPERATOR_JSON_FILE) do |file|
          JSON.parse(file)
        end
        json.as_h.delete("spec")
        File.write(OPERATOR_JSON_FILE, "#{json.to_json}")
        Log.info { `Uninstall Namespace Finalizer #{OPERATOR_JSON_FILE}` }
        if KubectlClient::Replace.command(`--raw '/api/v1/namespaces/operators/finalize' -f #{OPERATOR_JSON_FILE}`)[:status].success?
          delete = true
        end
        sleep 3
      end

      second_count = 0
      wait_count = 20
      delete = false
      until delete || second_count > wait_count.to_i
        File.write(MANAGER_JSON_FILE, "#{KubectlClient::Get.namespaces("operator-lifecycle-manager").to_json}")
        json = File.open(MANAGER_JSON_FILE) do |file|
          JSON.parse(file)
        end
        json.as_h.delete("spec")
        File.write(MANAGER_JSON_FILE, "#{json.to_json}")
        Log.info { `Uninstall Namespace Finalizer #{MANAGER_JSON_FILE}` }
        if KubectlClient::Replace.command(`--raw '/api/v1/namespaces/operator-lifecycle-manager/finalize' -f #{MANAGER_JSON_FILE}`)[:status].success?
          delete = true
        end
        sleep 3
      end

      File.delete(OPERATOR_JSON_FILE)
      File.delete(MANAGER_JSON_FILE)
    end

    it "'operator_test' test if operator is being used", tags: ["operator_test"] do
      begin
        LOGGING.info `./cnf-testsuite -l info cnf_setup cnf-path=./sample-cnfs/sample_operator`
        $?.success?.should be_true
        resp = `./cnf-testsuite -l info operator_installed`
        Log.info { "#{resp}" }
        (/PASSED: Operator is installed/ =~ resp).should_not be_nil
      ensure
        LOGGING.info `./cnf-testsuite -l info cnf_cleanup cnf-path=./sample-cnfs/sample_operator`
        $?.success?.should be_true
      end
    end

    it "'operator_privileged' test privileged operator NOT being used", tags: ["operator_privileged"] do
      begin
        LOGGING.info `./cnf-testsuite -l info cnf_setup cnf-path=./sample-cnfs/sample_operator`
        $?.success?.should be_true
        resp = `./cnf-testsuite -l info operator_privileged`
        Log.info { "#{resp}" }
        (/PASSED: Operator is NOT running with privileged rights/ =~ resp).should_not be_nil
      ensure
        LOGGING.info `./cnf-testsuite -l info cnf_cleanup cnf-path=./sample-cnfs/sample_operator`
        $?.success?.should be_true
      end
    end

    it "'operator_privileged' test if a privileged operator is being used", tags: ["operator_privileged"] do
      begin
        LOGGING.info `./cnf-testsuite -l info cnf_setup cnf-path=./sample-cnfs/sample_privileged_operator`
        $?.success?.should be_true
        resp = `./cnf-testsuite -l info operator_privileged`
        Log.info { "#{resp}" }
        (/FAILED: Operator is running with privileged rights/ =~ resp).should_not be_nil
      ensure
        LOGGING.info `./cnf-testsuite -l info cnf_cleanup cnf-path=./sample-cnfs/sample_privileged_operator`
        $?.success?.should be_true
      end
    end

  end
end

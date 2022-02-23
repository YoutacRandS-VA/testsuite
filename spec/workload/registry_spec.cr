require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "kubectl_client"
require "../../src/tasks/utils/system_information/helm.cr"
require "../../src/tasks/dockerd_setup.cr"
require "file_utils"
require "sam"

describe "Private Registry: Image" do
  before_all do
    install_registry = KubectlClient::Apply.file("#{TOOLS_DIR}/registry/manifest.yml")
    install_dockerd = KubectlClient::Apply.file("#{TOOLS_DIR}/dockerd/manifest.yml")
    KubectlClient::Get.resource_wait_for_install("Pod", "dockerd")
    KubectlClient::Get.resource_wait_for_install("Pod", "registry")

    KubectlClient.exec("dockerd -t -- apk add curl", force_output: true)
    KubectlClient.exec("dockerd -t -- curl http://example.com", force_output: true)

    if ENV["DOCKERHUB_USERNAME"]? && ENV["DOCKERHUB_PASSWORD"]?
      result = KubectlClient.exec("dockerd -t -- docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_PASSWORD", force_output: true)
      Log.info { "Docker Login output: #{result[:output]}" }
    else
      puts "DOCKERHUB_USERNAME & DOCKERHUB_PASSWORD Must be set.".colorize(:red)
      exit 1
    end

    KubectlClient.exec("dockerd -t -- docker pull coredns/coredns:1.6.7", force_output: true)
    KubectlClient.exec("dockerd -t -- docker tag coredns/coredns:1.6.7 registry:5000/coredns:1.6.7", force_output: true)
    KubectlClient.exec("dockerd -t -- docker push registry:5000/coredns:1.6.7", force_output: true)

    # This is required for the test that uses the sample_local_registry_org_image CNF
    KubectlClient.exec("dockerd -t -- docker tag coredns/coredns:1.6.7 registry:5000/coredns-sample-org/coredns:1.6.7", force_output: true)
    KubectlClient.exec("dockerd -t -- docker push registry:5000/coredns-sample-org/coredns:1.6.7", force_output: true)
  end

  it "'reasonable_image_size' should pass if using local registry and a port", tags: ["private_registry_image"]  do
    cnf="./sample-cnfs/sample_local_registry"

    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
    response_s = `./cnf-testsuite reasonable_image_size verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Image size is good/ =~ response_s).should_not be_nil
  ensure
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf}`
  end

  it "'reasonable_image_size' should pass if using local registry, a port and an org", tags: ["private_registry_image"]  do
    cnf="./sample-cnfs/sample_local_registry_org_image"

    LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
    response_s = `./cnf-testsuite reasonable_image_size verbose`
    LOGGING.info response_s
    $?.success?.should be_true
    (/Image size is good/ =~ response_s).should_not be_nil
  ensure
    LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf}`
  end

  after_all do
    delete_registry = KubectlClient::Delete.file("#{TOOLS_DIR}/registry/manifest.yml")
    delete_dockerd = KubectlClient::Delete.file("#{TOOLS_DIR}/dockerd/manifest.yml")
  end	
end

describe "Private Registry: Rolling" do
  before_all do
    install_registry = KubectlClient::Apply.file("#{TOOLS_DIR}/registry/manifest.yml")
    install_dockerd = KubectlClient::Apply.file("#{TOOLS_DIR}/dockerd/manifest.yml")
    KubectlClient::Get.resource_wait_for_install("Pod", "dockerd")
    KubectlClient::Get.resource_wait_for_install("Pod", "registry")

    KubectlClient.exec("dockerd -t -- apk add curl", force_output: true)
    KubectlClient.exec("dockerd -t -- curl http://example.com", force_output: true)

    KubectlClient.exec("dockerd -t -- docker pull coredns/coredns:1.6.7", force_output: true)
    KubectlClient.exec("dockerd -t -- docker tag coredns/coredns:1.6.7 registry:5000/coredns:1.6.7", force_output: true)
    KubectlClient.exec("dockerd -t -- docker push registry:5000/coredns:1.6.7", force_output: true)

    KubectlClient.exec("dockerd -t -- docker pull coredns/coredns:1.8.0", force_output: true)
    KubectlClient.exec("dockerd -t -- docker tag coredns/coredns:1.8.0 registry:5000/coredns:1.8.0", force_output: true)
    KubectlClient.exec("dockerd -t -- docker push registry:5000/coredns:1.8.0", force_output: true)
  end

  it "'rolling_update' should pass if using local registry and a port", tags: ["private_registry_rolling"]  do
    begin
      cnf="./sample-cnfs/sample_local_registry"

      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
      response_s = `./cnf-testsuite rolling_update verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Passed/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf} wait_count=0`
    end
  end

  it "'rolling_downgrade' should pass if using local registry and a port", tags: ["private_registry_rolling"]  do
    begin
      cnf="./sample-cnfs/sample_local_registry"

      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
      response_s = `./cnf-testsuite rolling_update verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Passed/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf} wait_count=0`
  	end
  end

  it "'rolling_version_change' should pass if using local registry and a port", tags: ["private_registry_version"]  do
    begin
      cnf="./sample-cnfs/sample_local_registry"

      LOGGING.info `./cnf-testsuite cnf_setup cnf-path=#{cnf}`
      response_s = `./cnf-testsuite rolling_version_change verbose`
      LOGGING.info response_s
      $?.success?.should be_true
      (/Passed/ =~ response_s).should_not be_nil
    ensure
      LOGGING.info `./cnf-testsuite cnf_cleanup cnf-path=#{cnf} wait_count=0`
    end
  end  

  after_all do
    delete_registry = KubectlClient::Delete.file("#{TOOLS_DIR}/registry/manifest.yml")
    delete_dockerd = KubectlClient::Delete.file("#{TOOLS_DIR}/dockerd/manifest.yml")
  end	
end

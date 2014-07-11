require 'json'

describe Lita::Handlers::GithubPrList, lita_handler: true do
  before :each do
    Lita.config.handlers.github_pr_list.github_organization = 'aaaaaabbbbbbcccccc'
    Lita.config.handlers.github_pr_list.github_access_token = 'wafflesausages111111'
    Lita.config.handlers.github_pr_list.web_hook = 'https://example.com/hook'
  end

  let(:agent) do
    Sawyer::Agent.new "http://example.com/a/" do |conn|
      conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
      conn.adapter :test, Faraday::Adapter::Test::Stubs.new
    end
  end

  def sawyer_resource_array(file_path)
    resources = []
    JSON.parse(File.read(file_path)).each do |i|
      resources << Sawyer::Resource.new(agent, i)
    end

    resources
  end

  let(:repos) { sawyer_resource_array("spec/fixtures/repository_list.json") }
  let(:hooks) { sawyer_resource_array("spec/fixtures/repository_hooks.json") }

  it { routes_command("pr add hooks").to(:add_pr_hooks) }
  it { routes_command("pr remove hooks").to(:remove_pr_hooks) }

  it "adds web hooks to an org's repos" do
    expect_any_instance_of(Octokit::Client).to receive(:repositories).and_return(repos)
    expect_any_instance_of(Octokit::Client).to receive(:create_hook).twice.and_return(nil)

    send_command("pr add hooks")

    expect(replies).to include("Adding webhooks to aaaaaabbbbbbcccccc, this may take awhile...")
    expect(replies).to include("Finished adding webhooks to aaaaaabbbbbbcccccc")
  end

  it "removes web hooks from an org's repos" do
    expect_any_instance_of(Octokit::Client).to receive(:repositories).and_return(repos)
    expect_any_instance_of(Octokit::Client).to receive(:hooks).twice.and_return(hooks)
    expect_any_instance_of(Octokit::Client).to receive(:remove_hook).twice.and_return(nil)

    send_command("pr remove hooks")

    expect(replies).to include("Removing https://example.com/hook webhooks from aaaaaabbbbbbcccccc, this may take awhile...")
    expect(replies).to include("Finished removing webhooks from aaaaaabbbbbbcccccc")
  end

  it "catches exceptions when the hook already exists and continues" do
    expect_any_instance_of(Octokit::Client).to receive(:repositories).and_return(repos)
    expect_any_instance_of(Octokit::Client).to receive(:create_hook).twice.and_return(nil)
    exception = Octokit::UnprocessableEntity.new
    allow(exception).to receive(:errors).and_return([OpenStruct.new(message: "Hook already exists on this repository")])
    allow(Lita::GithubPrList::WebHook).to receive(:create_hook).and_raise(exception)

    send_command("pr add hooks")

    expect(replies).to include("Adding webhooks to aaaaaabbbbbbcccccc, this may take awhile...")
    expect(replies).to include("Finished adding webhooks to aaaaaabbbbbbcccccc")
  end
end
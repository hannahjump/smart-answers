require "test_helper"

class ContentItemPublisherTest < ActiveSupport::TestCase
  setup do
    load_path = fixture_file("smart_answer_flows")
    SmartAnswer::FlowRegistry.stubs(:instance).returns(stub("Flow registry", find: @flow, load_path: load_path))
  end

  test "sending item to content store" do
    start_page_draft_request = stub_request(:put, "https://publishing-api.test.gov.uk/v2/content/3e6f33b8-0723-4dd5-94a2-cab06f23a685")
    start_page_publishing_request = stub_request(:post, "https://publishing-api.test.gov.uk/v2/content/3e6f33b8-0723-4dd5-94a2-cab06f23a685/publish")
    flow_draft_request = stub_request(:put, "https://publishing-api.test.gov.uk/v2/content/154829ba-ad5d-4dad-b11b-2908b7bec399")
    flow_publishing_request = stub_request(:post, "https://publishing-api.test.gov.uk/v2/content/154829ba-ad5d-4dad-b11b-2908b7bec399/publish")

    presenter = FlowRegistrationPresenter.new(stub("flow", name: "bridge-of-death", start_page_content_id: "3e6f33b8-0723-4dd5-94a2-cab06f23a685", flow_content_id: "154829ba-ad5d-4dad-b11b-2908b7bec399", external_related_links: nil, nodes: []))

    ContentItemPublisher.new.publish([presenter])

    assert_requested start_page_draft_request
    assert_requested start_page_publishing_request
    assert_requested flow_draft_request
    assert_requested flow_publishing_request
  end

  context "#unpublish" do
    should "send unpublish request to content store" do
      unpublish_url = "https://publishing-api.test.gov.uk/v2/content/content-id/unpublish"
      unpublish_request = stub_request(:post, unpublish_url)

      ContentItemPublisher.new.unpublish("content-id")

      assert_requested unpublish_request
    end

    should "raise exception if content_id has not been supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.unpublish(nil)
      end

      assert_equal "Content id has not been supplied", exception.message
    end
  end

  context "#reserve_path_for_publishing_app" do
    should "raise exception if base_path is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.reserve_path_for_publishing_app(nil, "publisher")
      end

      assert_equal "The destination or path isn't supplied", exception.message
    end

    should "raise exception if publishing_app is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.reserve_path_for_publishing_app("/base_path", nil)
      end

      assert_equal "The destination or path isn't supplied", exception.message
    end

    should "send a base_path publishing_app reservation request" do
      reservation_url = "https://publishing-api.test.gov.uk/paths//base_path"
      reservation_request = stub_request(:put, reservation_url)

      ContentItemPublisher.new.reserve_path_for_publishing_app("/base_path", "publisher")

      assert_requested reservation_request
    end
  end

  context "#publish_transaction" do
    setup do
      SecureRandom.stubs(:uuid).returns("content-id")
      create_url = "https://publishing-api.test.gov.uk/v2/content/content-id"
      @create_request = stub_request(:put, create_url)
      publish_url = "https://publishing-api.test.gov.uk/v2/content/content-id/publish"
      @publish_request = stub_request(:post, publish_url)
    end

    should "raise exception if base_path is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_transaction(
          nil,
          publishing_app: "publisher",
          title: "Sample transaction title",
          content: "Sample transaction content",
          link: "https://smaple.gov.uk/path/to/somewhere",
        )
      end

      assert_equal "The base path isn't supplied", exception.message
    end

    should "raise exception if publishing_app is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_transaction(
          "/base-path",
          publishing_app: nil,
          title: "Sample transaction title",
          content: "Sample transaction content",
          link: "https://smaple.gov.uk/path/to/somewhere",
        )
      end

      assert_equal "The publishing_app isn't supplied", exception.message
    end

    should "raise exception if title is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_transaction(
          "/base-path",
          publishing_app: "publisher",
          title: nil,
          content: "Sample transaction content",
          link: "https://smaple.gov.uk/path/to/somewhere",
        )
      end

      assert_equal "The title isn't supplied", exception.message
    end

    should "raise exception if content is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_transaction(
          "/base-path",
          publishing_app: "publisher",
          title: "Sample transaction title",
          content: nil,
          link: "https://smaple.gov.uk/path/to/somewhere",
        )
      end

      assert_equal "The content isn't supplied", exception.message
    end

    should "raise exception if link is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_transaction(
          "/base-path",
          publishing_app: "publisher",
          title: "Sample transaction title",
          content: "Sample transaction content",
          link: nil,
        )
      end

      assert_equal "The link isn't supplied", exception.message
    end

    should "send publish transaction request to publishing-api" do
      ContentItemPublisher.new.publish_transaction(
        "/base-path",
        publishing_app: "publisher",
        title: "Sample transaction title",
        content: "Sample transaction content",
        link: "https://smaple.gov.uk/path/to/somewhere",
      )

      assert_requested @create_request
      assert_requested @publish_request
    end

    should "raise exception and not attempt publishing transaction when create request fails" do
      GdsApi::Response.any_instance.stubs(:code).returns(500)
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_transaction(
          "/base-path",
          publishing_app: "publisher",
          title: "Sample transaction title",
          content: "Sample transaction content",
          link: "https://smaple.gov.uk/path/to/somewhere",
        )
      end

      assert_equal "This content item has not been created", exception.message
      assert_requested @create_request
      assert_not_requested @publish_request
    end
  end

  context "#publish_answer" do
    setup do
      SecureRandom.stubs(:uuid).returns("content-id")
      create_url = "https://publishing-api.test.gov.uk/v2/content/content-id"
      @create_request = stub_request(:put, create_url)
      publish_url = "https://publishing-api.test.gov.uk/v2/content/content-id/publish"
      @publish_request = stub_request(:post, publish_url)
    end

    should "send publish answer request to publishing-api" do
      ContentItemPublisher.new.publish_answer(
        "/base-path",
        publishing_app: "publisher",
        title: "Sample answer title",
        content: "Sample answer content",
      )

      assert_requested @create_request
      assert_requested @publish_request
    end

    should "raise exception and not attempt publishing answer when create request fails" do
      GdsApi::Response.any_instance.stubs(:code).returns(500)
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_answer(
          "/base-path",
          publishing_app: "publisher",
          title: "Sample answer title",
          content: "Sample answer content",
        )
      end

      assert_equal "This content item has not been created", exception.message
      assert_requested @create_request
      assert_not_requested @publish_request
    end

    should "raise exception if base_path is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_answer(
          nil,
          publishing_app: "publisher",
          title: "Sample answer title",
          content: "Sample answer content",
        )
      end

      assert_equal "The base path isn't supplied", exception.message
    end

    should "raise exception if publishing_app is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_answer(
          "/base-path",
          publishing_app: nil,
          title: "Sample answer title",
          content: "Sample answer content",
        )
      end

      assert_equal "The publishing_app isn't supplied", exception.message
    end

    should "raise exception if title is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_answer(
          "/base-path",
          publishing_app: "publisher",
          title: nil,
          content: "Sample answer content",
        )
      end

      assert_equal "The title isn't supplied", exception.message
    end

    should "raise exception if content is not supplied" do
      exception = assert_raises(RuntimeError) do
        ContentItemPublisher.new.publish_answer(
          "/base-path",
          publishing_app: "publisher",
          title: "Sample answer title",
          content: nil,
        )
      end

      assert_equal "The content isn't supplied", exception.message
    end
  end
end

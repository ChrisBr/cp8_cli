require "test_helper"

module Cp8Cli
  class MainTest < Minitest::Test
    def setup
      stub_shell
      stub_trello(:get, "/tokens/MEMBER_TOKEN/member").to_return_json(member)
      stub_request(:get, /api\.rubygems\.org/).to_return_json({})
    end

    def test_git_start_from_url
      card_endpoint = stub_trello(:get, "/cards/CARD_SHORT_LINK").to_return_json(card)
      board_endpoint = stub_trello(:get, "/boards/BOARD_ID").to_return_json(board)
      lists_endpoint = stub_trello(:get, "/boards/BOARD_ID/lists").to_return_json([backlog, started, finished])
      move_to_list_endpoint = stub_trello(:put, "/cards/CARD_ID/idList").with(body: { value: "STARTED_LIST_ID" })
      add_member_endpoint = stub_trello(:post, "/cards/CARD_ID/members").with(body: { value: "MEMBER_ID" })
      stub_branch("master")
      stub_github_user("John Bobson")

      expect_checkout("jb.card-name.master.CARD_SHORT_LINK")

      cli.start(card_url)

      shell.verify
      assert_requested card_endpoint
      assert_requested board_endpoint
      assert_requested lists_endpoint
      assert_requested move_to_list_endpoint
      assert_requested add_member_endpoint
    end

    def test_git_start_with_name
      lists_endpoint = stub_trello(:get, "/boards/BOARD_ID/lists").to_return_json([backlog, started, finished])
      create_card_endpoint = stub_trello(:post, "/lists/BACKLOG_LIST_ID/cards").to_return_json(card)
      board_endpoint = stub_trello(:get, "/boards/BOARD_ID").to_return_json(board)
      labels_endpoint = stub_trello(:get, "/boards/BOARD_ID/labels").to_return_json([label])
      add_label_endpoint = stub_trello(:post, "/cards/CARD_ID/idLabels").with(body: { value: "LABEL_ID" }).to_return_json(["LABEL_ID"])
      move_to_list_endpoint = stub_trello(:put, "/cards/CARD_ID/idList").with(body: { value: "STARTED_LIST_ID" })
      add_member_endpoint = stub_trello(:post, "/cards/CARD_ID/members").with(body: { value: "MEMBER_ID" })
      stub_branch("master")
      stub_github_user("John Bobson")

      shell.expect :table, nil, [Array] # Pick label
      shell.expect :ask, 1, ["Add label:", type: Integer]
      expect_checkout("jb.card-name.master.CARD_SHORT_LINK")

      cli.start("NEW CARD NAME")

      shell.verify
      assert_requested lists_endpoint, times: 2
      assert_requested create_card_endpoint
      assert_requested board_endpoint, times: 2
      assert_requested labels_endpoint
      assert_requested add_label_endpoint
      assert_requested move_to_list_endpoint
      assert_requested add_member_endpoint
    end

    def test_git_start_with_blank_name
      lists_endpoint = stub_trello(:get, "/boards/BOARD_ID/lists").to_return_json([backlog, started, finished])
      cards_endpoint = stub_trello(:get, "/lists/BACKLOG_LIST_ID/cards").to_return_json([card])
      board_endpoint = stub_trello(:get, "/boards/BOARD_ID").to_return_json(board)
      move_to_list_endpoint = stub_trello(:put, "/cards/CARD_ID/idList").with(body: { value: "STARTED_LIST_ID" })
      add_member_endpoint = stub_trello(:post, "/cards/CARD_ID/members").with(body: { value: "MEMBER_ID" })
      stub_branch("master")
      stub_github_user("John Bobson")

      shell.expect :table, nil, [Array] # Pick column
      shell.expect :ask, 1, ["Pick one:", type: Integer]
      expect_checkout("jb.card-name.master.CARD_SHORT_LINK")

      cli.start(nil)

      shell.verify
      assert_requested lists_endpoint, times: 2
      assert_requested cards_endpoint
      assert_requested board_endpoint, times: 2
      assert_requested move_to_list_endpoint
      assert_requested add_member_endpoint
    end

    def test_git_start_github_issue
      issue_endpoint = stub_github(:get, "/repos/balvig/cp8_cli/issues/ISSUE_NUMBER").to_return_json(github_issue)
      user_endpoint = stub_github(:get, "/user").to_return_json(github_user)
      assign_endpoint = stub_github(:post, "/repos/balvig/cp8_cli/issues/ISSUE_NUMBER/assignees").
        with(body: { assignees: ["GITHUB_USER"] })
      stub_branch("master")
      stub_github_user("John Bobson")

      expect_checkout("jb.issue-title.master.balvig/cp8_cli#ISSUE_NUMBER")

      cli.start("https://github.com/balvig/cp8_cli/issues/ISSUE_NUMBER")

      shell.verify

      assert_requested issue_endpoint
      assert_requested user_endpoint
      assert_requested assign_endpoint
    end

    def test_git_start_release_branch
      stub_trello(:get, "/boards/BOARD_ID/lists").to_return_json([backlog, started, finished])
      stub_trello(:get, "/lists/BACKLOG_LIST_ID/cards").to_return_json([card])
      stub_trello(:get, "/boards/BOARD_ID").to_return_json(board)
      stub_trello(:put, "/cards/CARD_ID/idList")
      stub_trello(:post, "/cards/CARD_ID/members")
      stub_branch("release-branch")
      stub_github_user("John Bobson")

      shell.expect :table, nil, [Array] # Pick column
      shell.expect :ask, 1, ["Pick one:", type: Integer]
      expect_checkout("jb.card-name.release-branch.CARD_SHORT_LINK")

      cli.start(nil)

      shell.verify
    end


    def test_git_open_master
      stub_branch("master")

      expect_error("Not currently on story branch")

      cli.open

      shell.verify
    end

    def test_git_open_card
      stub_trello(:get, "/cards/CARD_SHORT_LINK").to_return_json(card)
      stub_branch("jb.card-name.master.CARD_SHORT_LINK")

      expect_open_url("https://trello.com/c/CARD_SHORT_LINK/2-trello-flow")

      cli.open

      shell.verify
    end

    def test_git_submit
      card_endpoint = stub_trello(:get, "/cards/CARD_SHORT_LINK").to_return_json(card)
      stub_branch("jb.card-name.master.CARD_SHORT_LINK")
      stub_repo("git@github.com:balvig/cp8_cli.git")

      expect_push("jb.card-name.master.CARD_SHORT_LINK")
      expect_pr(
        repo: "balvig/cp8_cli",
        from: "jb.card-name.master.CARD_SHORT_LINK",
        to: "master",
        title: "CARD NAME [Delivers #CARD_SHORT_LINK]",
        body: "Trello: #{card_short_url}\n\n_Release note: CARD NAME_"
      )

      cli.submit

      shell.verify
      assert_requested card_endpoint
    end

    def test_submit_wip
      stub_trello(:get, "/cards/CARD_SHORT_LINK").to_return_json(card)
      stub_branch("jb.card-name.master.CARD_SHORT_LINK")
      stub_repo("git@github.com:balvig/cp8_cli.git")

      expect_push("jb.card-name.master.CARD_SHORT_LINK")
      expect_pr(
        repo: "balvig/cp8_cli",
        from: "jb.card-name.master.CARD_SHORT_LINK",
        to: "master",
        title: "[WIP] CARD NAME [Delivers #CARD_SHORT_LINK]",
        body: "Trello: #{card_short_url}\n\n_Release note: CARD NAME_"
      )

      cli.submit(wip: true)

      shell.verify
    end

    def test_git_submit_github_issue
      issue_endpoint = stub_github(:get, "/repos/balvig/cp8_cli/issues/ISSUE_NUMBER").to_return_json(github_issue)
      stub_branch("jb.issue-title.master.balvig/cp8_cli#ISSUE_NUMBER")
      stub_repo("git@github.com:balvig/cp8_cli.git")

      expect_push("jb.issue-title.master.balvig/cp8_cli#ISSUE_NUMBER")
      expect_pr(
        repo: "balvig/cp8_cli",
        from: "jb.issue-title.master.balvig/cp8_cli#ISSUE_NUMBER",
        to: "master",
        title: "ISSUE TITLE",
        body: "Closes balvig/cp8_cli#ISSUE_NUMBER\n\n_Release note: ISSUE TITLE_"
      )

      cli.submit

      shell.verify
      assert_requested issue_endpoint
    end

    def test_wrong_credentials
      stub_trello(:get, "/boards/BOARD_ID").to_return(invalid_token)

      expect_error("invalid token")

      cli.start(nil)

      shell.verify
    end

    def test_inexistent_card
      stub_trello(:get, "/cards/CARD_SHORT_LINK").to_return(invalid_card_id)

      expect_error("invalid id")

      cli.start(card_url)

      shell.verify
    end

    def test_open_ci
      stub_branch("jb.issue-title.master.balvig/cp8_cli#ISSUE_NUMBER")
      stub_repo("git@github.com:balvig/cp8_cli.git")

      expect_open_url("https://circleci.com/gh/balvig/cp8_cli/tree/jb.issue-title.master.balvig%2Fcp8_cli%23ISSUE_NUMBER")

      cli.ci

      shell.verify
    end

    private

      def card_short_link
        "CARD_SHORT_LINK"
      end

      def card_short_url
        "https://trello.com/c/#{card_short_link}"
      end

      def card_url
        "#{card_short_url}/2-trello-flow"
      end

      def board_url
        "https://trello.com/b/qdC0CNy0/2-trello-flow-board"
      end

      def member
        { id: "MEMBER_ID", username: "balvig", initials: "JB" }
      end

      def board
        { name: "BOARD NAME", id: "BOARD_ID", url: board_url }
      end

      def backlog
        { id: "BACKLOG_LIST_ID" }
      end

      def started
        { id: "STARTED_LIST_ID" }
      end

      def finished
        { id: "FINISHED_LIST_ID" }
      end

      def card
        { id: "CARD_ID", name: "CARD NAME", idBoard: "BOARD_ID", url: card_url, shortUrl: card_short_url }
      end

      def label
        { id: "LABEL_ID", name: "LABEL NAME" }
      end

      def github_issue
        { number: "ISSUE_NUMBER", title: "ISSUE TITLE"}
      end

      def github_user
        { login: "GITHUB_USER" }
      end

      def invalid_token
        { status: 400, body: "invalid token" }
      end

      def invalid_card_id
        { status: 302, body: "invalid id" }
      end

      def cli
        @_cli ||= Main.new global_config, LocalConfig.new(board_id: "BOARD_ID")
      end

      def global_config
        GlobalConfig.new(key: "PUBLIC_KEY", token: "MEMBER_TOKEN", github_token: "GITHUB_TOKEN")
      end
  end
end

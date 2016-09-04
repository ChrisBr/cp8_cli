require 'test_helper'

module Dolma
  class DolmaTest < Minitest::Test
    def setup
      Cli.client = cli
    end

    def test_git_start
      card_endpoint = stub_trello(:get, "/cards/CARD_ID").to_return_json(card)
      checklists_endpoint = stub_trello(:get, "/cards/CARD_ID/checklists").with(query: { filter: "all" }).to_return_json([checklist])
      checklist_endpoint = stub_trello(:get, "/checklists/CHECKLIST_ID").to_return_json(checklist)
      update_item_endpoint = stub_trello(:put, "/cards/CARD_ID/checklist/CHECKLIST_ID/checkItem/ITEM_ID/name").with(body: { value: "ITEM TASK @balvig" })

      cli.expect :title, nil, ["CARD NAME (CHECKLIST NAME)"]
      cli.expect :table, nil, [Array]
      cli.expect :ask, 1, ["Pick one:", Integer]
      cli.expect :run, nil, ["git checkout -b master.item-task.CHECKLIST_ID-ITEM_ID"]

      dolma.start("https://trello.com/c/CARD_ID/2-trello-flow")

      cli.verify
      assert_requested card_endpoint, at_least_times: 1
      assert_requested checklists_endpoint, at_least_times: 1
      assert_requested checklist_endpoint, at_least_times: 1
      assert_requested update_item_endpoint, at_least_times: 1
    end

    private

      def card
        { id: "CARD_ID", name: "CARD NAME" }
      end

      def checklist
        { id: "CHECKLIST_ID", name: "CHECKLIST NAME", checkItems: [item], idCard: "CARD_ID" }
      end

      def item
        { id: "ITEM_ID", name: "ITEM TASK @owner", idChecklist: "CHECKLIST_ID" }
      end

      def cli
        @_cli ||= Minitest::Mock.new
      end

      def dolma
        @_dolma ||= Main.new Config.new(public_key: "PUBLIC_KEY", member_token: "MEMBER_TOKEN")
      end
  end
end

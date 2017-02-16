require "spyke"
require "trello_flow/api/json_parser"
require "trello_flow/api/error_handler"

Faraday::Response.register_middleware json_parser: -> { TrelloFlow::Api::JSONParser }
Faraday::Response.register_middleware error_handler: -> { TrelloFlow::Api::ErrorHandler }

module TrelloFlow
  module Api
    class Base < Spyke::Base
      require "trello_flow/api/board"
      require "trello_flow/api/card"
      require "trello_flow/api/label"
      require "trello_flow/api/list"
      require "trello_flow/api/member"

      include_root_in_json false
      cattr_accessor :token

      def self.configure(key:, token:)
        self.connection = Faraday.new(url: "https://api.trello.com/1", params: { key: key, token: token }) do |c|
          c.request  :json
          c.response :json_parser
          c.response :error_handler
          c.adapter  Faraday.default_adapter

          # For trello api logging
          # require "faraday/conductivity"
          # c.use       Faraday::Conductivity::ExtendedLogging
        end
        self.token = token
      end

      def position
        self[:pos].to_f
      end
    end
  end
end

# frozen_string_literal: true
require_relative '../base_module/response'
module ::HelloModule
  class ExamplesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render json: { hello: "world" }
    end

  end
end

# frozen_string_literal: true

module ::HelloModule
  class ExamplesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index

      render json: { hello: "world", setting:  SiteSetting.awesomeness_max_volume }
    end

  end
end

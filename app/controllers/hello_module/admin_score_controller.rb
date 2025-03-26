module ::HelloModule
  class AdminScoreController < AdminCommonController
    include MyHelper
    include PostHelper
    requires_plugin PLUGIN_NAME
    before_action :set_current_user

    def list
      page = (params[:page] || 1).to_i
      size = (params[:size] || 10).to_i
      search_term = params[:search].presence

      query = User
        .joins("INNER JOIN gamification_leaderboard_cache_1_all_time p ON  p.user_id = users.id")
        .joins("LEFT JOIN uploads ON uploads.id = users.uploaded_avatar_id")

      if search_term.present?
        query = query.where("users.username LIKE ?", "%#{search_term}%")
      end

      total = query.count

      res = query
              .select(
        "users.id, users.name, users.username, users.uploaded_avatar_id, p.total_score, p.position, uploads.url",
        )
        .order(position: :asc, id: :asc)
        .limit(size).offset((page - 1) * size)

      res = res.map do |user|
        user.url = format_url(user.url)
        user
      end

      res = res.as_json(only: [:id, :name, :username, :total_score, :position, :url])

      render_response(data: create_page_list(res, total, page, size ))
    end

    def event_list
      page = (params[:page] || 1).to_i
      size = (params[:size] || 10).to_i
      params.permit(%i[id date username])

      query = DiscourseGamification::GamificationScoreEvent
      .joins("INNER JOIN users ON users.id = gamification_score_events.user_id")
      .order(id: :desc)
      query = query.where("users.username LIKE ?", "%#{params[:username]}%") if params[:username].present?
      query = query.where(date: params[:date]) if params[:date].present?

      count = query.count
      events = query.select("gamification_score_events.id, gamification_score_events.user_id, gamification_score_events.date, gamification_score_events.points, gamification_score_events.description, users.username").limit(size).offset((page - 1) * size)
      res = events.as_json(only: %i[id user_id date points description username])

      render_response(data: create_page_list(res, count, page, size ))
    end

    def event_create
      params.require(%i[user_id points])
      params.permit(:description)

      event =
        DiscourseGamification::GamificationScoreEvent.new(
          user_id: params[:user_id],
          date: Time.now, # now
          points: params[:points],
          description: params[:description],
          )

      if event.save
        res = event.as_json(only: %i[id user_id date points description])
        render_response(data: res)
      else
        render_response(success: false, msg: event.errors.full_messages.join(", "))
      end
    end

    def user_list
      page = (params[:page] || 1).to_i
      size = (params[:size] || 10).to_i
      search_term = params[:search].presence

      # join user_email
      query = User
                .joins("LEFT JOIN uploads ON uploads.id = users.uploaded_avatar_id")
                .joins("LEFT JOIN user_emails ON user_emails.user_id = users.id")
                .where("users.id > ?", 0)

      if search_term.present?
        query = query.where("users.username LIKE ?", "%#{search_term}%")
      end

      total = query.count

      res = query.select(
        "users.id, users.username, user_emails.email, uploads.url",
        )
        .limit(size).offset((page - 1) * size)

      res = res.map do |user|
        user.url = format_url(user.url)
        user
      end

      res = res.as_json(only: [:id, :username, :name, :email, :url])

      render_response(data: create_page_list(res, total, page, size ))
    end

  end
end

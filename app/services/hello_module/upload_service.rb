module ::HelloModule
  class UploadService
    extend PostHelper
    extend DiscourseHelper

    def self.upload_image(file, upload_user, params)
      url = params[:url]
      pasted = params[:pasted] == "true"
      for_private_message = params[:for_private_message] == "true"
      for_site_setting = params[:for_site_setting] == "true"
      is_api = false
      retain_hours = params[:retain_hours].to_i
      type = "composer"
      begin
        info = UploadsController.create_upload(
          current_user: upload_user,
          file: file,
          url: url,
          type: type,
          for_private_message: for_private_message,
          for_site_setting: for_site_setting,
          pasted: pasted,
          is_api: is_api,
          retain_hours: retain_hours,
        )
      rescue => e
        result = failed_json.merge(message: e.message.split("\n").first)
      else
        result = UploadsController.serialize_upload(info)
      end

      result
    end


  end
end

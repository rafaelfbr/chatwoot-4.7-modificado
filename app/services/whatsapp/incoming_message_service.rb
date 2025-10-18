# https://docs.360dialog.com/whatsapp-api/whatsapp-api/media
# https://developers.facebook.com/docs/whatsapp/api/media/

class Whatsapp::IncomingMessageService < Whatsapp::IncomingMessageBaseService

  private

  def create_regular_message(message)
    content_attrs = {}
    
    if @referral_data.present?
      content_attrs[:whatsapp] = {
        referral: @referral_data
      }
    end

    @message = @conversation.messages.build(
      content: message_content(message),
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: message[:id].to_s,
      in_reply_to_external_id: @in_reply_to_external_id,
      content_attributes: content_attrs
    )

    attach_files
    attach_location if message_type == 'location'
    @message.save!
  end

end
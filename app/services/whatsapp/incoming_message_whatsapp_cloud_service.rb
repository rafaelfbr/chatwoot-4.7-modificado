# https://docs.360dialog.com/whatsapp-api/whatsapp-api/media
# https://developers.facebook.com/docs/whatsapp/api/media/

class Whatsapp::IncomingMessageWhatsappCloudService < Whatsapp::IncomingMessageBaseService
  # Adicionamos a variável para carregar os dados do referral entre os métodos
  attr_accessor :referral_data

  private

  #
  # Métodos que já existiam neste arquivo (mantidos)
  #
  def processed_params
    @processed_params ||= params[:entry].try(:first).try(:[], 'changes').try(:first).try(:[], 'value')
  end

  def download_attachment_file(attachment_payload)
    url_response = HTTParty.get(
      inbox.channel.media_url(
        attachment_payload[:id],
        inbox.channel.provider_config['phone_number_id']
      ),
      headers: inbox.channel.api_headers
    )
    # This url response will be failure if the access token has expired.
    inbox.channel.authorization_error! if url_response.unauthorized?
    Down.download(url_response.parsed_response['url'], headers: inbox.channel.api_headers) if url_response.success?
  end

  #
  # Métodos copiados da classe 'pai' e MODIFICADOS com LOGS
  #
  def create_messages
    message = @processed_params[:messages].first
    log_error(message) && return if error_webhook_event?(message)

    # AQUI CAPTURAMOS O REFERRAL
    @referral_data = message[:referral]
    Rails.logger.info "[REFERRAL DEBUG] create_messages: Referral data capturado: #{@referral_data.inspect}"

    process_in_reply_to(message)
    message_type == 'contacts' ? create_contact_messages(message) : create_regular_message(message)
  end

  def create_regular_message(message)
    Rails.logger.info "[REFERRAL DEBUG] create_regular_message: Iniciando. @referral_data é: #{@referral_data.inspect}"

    # Prepara os atributos com o referral
    content_attrs = {}
    if @referral_data.present?
      content_attrs[:whatsapp] = {
        referral: @referral_data
      }
    end
    Rails.logger.info "[REFERRAL DEBUG] create_regular_message: content_attrs preparado: #{content_attrs.inspect}"

    # Constrói a mensagem JÁ COM OS ATRIBUTOS
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

    Rails.logger.info "[REFERRAL DEBUG] create_regular_message: Mensagem construída com attributes: #{@message.content_attributes.inspect}"

    attach_files
    attach_location if message_type == 'location'
    @message.save!

    Rails.logger.info "[REFERRAL DEBUG] create_regular_message: Mensagem salva com ID #{@message.id}. Attributes no banco: #{@message.reload.content_attributes.inspect}"
  end
end


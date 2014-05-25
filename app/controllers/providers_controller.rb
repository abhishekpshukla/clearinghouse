class ProvidersController < ApplicationController
  load_and_authorize_resource
  before_filter :admins_only, :only => :index

  before_filter :only => [:create, :update] do
    allow_blank_time_field(@provider, :trip_ticket_expiration_time_of_day)
  end

  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @providers }
    end
  end

  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @provider }
    end
  end

  def new
    @provider.build_address
    create_provider_admin_user_for_forms
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @provider }
    end
  end

  def edit
  end

  def create
    @provider.active = true
    respond_to do |format|
      if @provider.save
        format.html { redirect_to providers_path, notice: 'Provider was successfully created.' }
        format.json { render json: @provider, status: :created, location: @provider }
      else
        create_provider_admin_user_for_forms
        format.html { render action: "new" }
        format.json { render json: @provider.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @provider = Provider.find(params[:id])
    respond_to do |format|
      if @provider.update_attributes(params[:provider])
        format.html { redirect_to providers_path, notice: 'Provider was successfully updated.' }
        format.json { render json: @provider }
      else
        format.html { render action: "edit" }
        format.json { render json: @provider.errors, status: :unprocessable_entity }
      end
    end
  end

  def activate
    params[:provider] = { :active => true }
    update
  end

  def deactivate
    params[:provider] = { :active => false }
    update
  end

  def keys; end

  def reset_keys
    # Make sure we can audit this action via the log files
    logger.info "User #{current_user.to_param} is attempting to reset the API keys for Provider #{@provider.to_param}"
    
    @provider.errors.add(:base, "You must enter your password")   unless current_user.valid_password?(params[:reset_keys][:password])
    @provider.errors.add(:base, "You must accept the disclaimer") unless params[:reset_keys][:accept] == "1"
    
    respond_to do |format|
      if @provider.errors.blank? && @provider.regenerate_keys!
        format.html { redirect_to keys_provider_path(@provider), notice: "Your API keys have been regenerated. You MUST update your adapter configuration to continue to use the Clearinghouse API."}
        format.json { head :no_content }
      else
        format.html { render action: "keys" }
        format.json { render json: @provider.errors, status: :unprocessable_entity }
      end
    end
  end

  protected

  def create_provider_admin_user_for_forms
    if @provider.new_record?
      user_params = params[:provider].try(:[], :users_attributes).try(:[], '0') || {}
      user_params[:role_id] = Role.where(name: 'provider_admin').pluck(:id).first
      @user = @provider.users.build(user_params)
    end
  end

end
require 'entities_v1'

module Clearinghouse
  class API_v1 < Grape::API

    helpers APIHelpers

    version 'v1', :using => :path, :vendor => 'Clearinghouse' do
      namespace :originator do
        desc "Says hello"
        get :hello do
          "Hello, originator!"
        end
      end
      
      namespace :claimant do
        desc "Says hello"
        get :hello do
          "Hello, claimant!"
        end
      end
      
      namespace :users do
        desc "Get a list of users belonging to this provider"
        get do
          present current_provider.users, with: Clearinghouse::Entities::V1::User
        end

        params do
          requires :id, :type => Integer, :desc => 'User ID.'
        end
        scope :requires_id do
          desc "Get a specific user"
          get :show do
            present current_provider.users.find(params[:id]), with: Clearinghouse::Entities::V1::User
          end
        
          desc "Update a specific user"
          put :update do
            user = current_provider.users.find(params[:id])

            if params[:user] && params[:user].try(:[], :password).blank?
              params[:user].delete("password")
              params[:user].delete("password_confirmation")
            end

            if user.update_attributes(params[:user])
              present user, with: Clearinghouse::Entities::V1::User
            else
              error!({message: "Could not update user", errors: user.errors}, status: :unprocessable_entity)
            end
          end
        
          desc "Activates a specific user"
          put :activate do
            user = current_provider.users.find(params[:id])

            if user.update_attribute(:active, true)
              present user, with: Clearinghouse::Entities::V1::User
            else
              error!({message: "Could not activate user", errors: user.errors}, status: :unprocessable_entity)
            end
          end
        
          desc "Activates a specific user"
          put :deactivate do
            user = current_provider.users.find(params[:id])
          
            if user.update_attribute(:active, false)
              present user, with: Clearinghouse::Entities::V1::User
            else
              error!({message: "Could not deactivate user", errors: user.errors}, status: :unprocessable_entity)
            end
          end
        end
      end
      
      namespace :provider do
        desc "Get details about the current provider"
        get do
          present current_provider, with: Clearinghouse::Entities::V1::Provider
        end
        
        desc "Update the current provider (currently limited to primary_contact_email only)"
        put :update do
          # currently limited to primary_contact_email only
          allowed_params = params[:provider].select{|k,v| [:primary_contact_email].include?(k.to_sym) }
          if current_provider.update_attributes(allowed_params)
            present current_provider, with: Clearinghouse::Entities::V1::Provider
          else
            error!({message: "Could not update provider", errors: current_provider.errors}, status: :unprocessable_entity)
          end
        end
      end

      namespace :trip_tickets do
        desc "Get list of trips accessible to the requesting provider"
        #params do
          # TODO add all available trip filters as optional params with descriptions so the API is self-documenting
        #end
        get do
          present trip_tickets_filter(TripTicket.accessible_by(current_ability)), with: Clearinghouse::Entities::V1::TripTicket
        end

        # TODO add all available parameters to create/update actions so API is self-documenting
        #params do
          #group :trip_ticket do
            #requires :customer_dob, :customer_first_name, :customer_last_name,
            #  :customer_primary_phone, :customer_seats_required, :origin_customer_id,
            #  :requested_drop_off_time, :requested_pickup_time
          #end
        #end
        desc "Create a trip ticket"
        put :create do
          trip_ticket = TripTicket.new(params[:trip_ticket])
          trip_ticket.origin_provider_id ||= current_provider.id
          error! "Access Denied", 401 unless current_ability.can?(:create, trip_ticket)
          if trip_ticket.save
            present trip_ticket, with: Clearinghouse::Entities::V1::TripTicket
          else
            error!({message: "Could not create trip ticket", errors: trip_ticket.errors}, status: :unprocessable_entity)
          end
        end

        params do
          requires :id, :type => Integer, :desc => 'Trip ticket ID.'
        end
        scope :requires_id do
          desc "Get a specific trip ticket"
          get :show do
            # to allow CanCan abilities to fully control access to tickets, do not limit scope to provider's own trips
            trip_ticket = TripTicket.find(params[:id])
            error! "Access Denied", 401 unless current_ability.can?(:show, trip_ticket)
            present trip_ticket, with: Clearinghouse::Entities::V1::TripTicket
          end

          desc "Update a trip ticket"
          put :update do
            trip_ticket = TripTicket.find(params[:id])
            error! "Access Denied", 401 unless current_ability.can?(:update, trip_ticket)
            if trip_ticket.update_attributes(params[:trip_ticket])
              present trip_ticket, with: Clearinghouse::Entities::V1::TripTicket
            else
              error!({message: "Could not update trip ticket", errors: trip_ticket.errors}, status: :unprocessable_entity)
            end
          end

          # TODO pending implementation of a TripTicket#cancel method
          #desc "Cancel a trip ticket"
          #put :cancel do
          #  trip_ticket = TripTicket.find(params[:id])
          #  error! "Access Denied", 401 unless current_ability.can?(:cancel, trip_ticket)
          #  if trip_ticket.cancel
          #    present trip_ticket, with: Clearinghouse::Entities::V1::TripTicket
          #  else
          #    error!({message: "Could not cancel trip ticket", errors: trip_ticket.errors}, status: :unprocessable_entity)
          #  end
          #end
        end # scope :requires_id
      end # namespace :trip_tickets

    end
  end
end

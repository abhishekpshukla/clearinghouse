require 'notification_recipients'

class TripClaim < ActiveRecord::Base
  include NotificationRecipients

  belongs_to :trip_ticket, :touch => true
  belongs_to :claimant, :class_name => :Provider, :foreign_key => :claimant_provider_id
  
  ACTIVE_STATUS = [
    :pending,
    :approved
  ]

  INACTIVE_STATUS = [
    :declined,
    :rescinded
  ]

  STATUS = ACTIVE_STATUS + INACTIVE_STATUS

  validates_presence_of :claimant_provider_id, :trip_ticket_id, :proposed_pickup_time
    
  validates :status, :presence => true, :inclusion => { :in => STATUS }
    
  validate :trip_ticket_is_not_claimed, :one_claim_per_trip_ticket_per_claimant

  validate :trip_ticket_is_not_rescinded, :on => :create

  audited allow_mass_assignment: true

  acts_as_notifier do
    after_create do
      notify ->(opts){ provider_users(trip_ticket.originator, opts) }, if: proc{ !can_be_auto_approved? }, method: :claim_for_approval
      notify ->(opts){ provider_users([trip_ticket.originator, claimant], opts) }, if: proc{ can_be_auto_approved? }, method: :claim_auto_approved
    end
    after_save do
      notify ->(opts){ provider_users(claimant, opts) }, if: proc{ status_changed? && status == :approved && !can_be_auto_approved? }, method: :claim_approved
      notify ->(opts){ provider_users(claimant, opts) }, if: proc{ status_changed? && status == :declined }, method: :claim_declined
      notify ->(opts){ provider_users(trip_ticket.originator, opts) }, if: proc{ status_changed? && status == :rescinded }, method: :claim_rescinded
    end
  end

  default_scope ->{ order 'trip_claims.created_at ASC' }
  
  after_create do
    self.approve! if self.can_be_auto_approved?
  end

  def claimant_name
    claimant.try(:name)
  end
  
  def status
    super.try(:to_sym)
  end

  def status=(value)
    super(value.to_sym)
    status
  end

  def approve!
    self.status = :approved
    save!
    trip_ticket.trip_claims.where('id != ? AND status NOT IN (?)', self.id, INACTIVE_STATUS.map(&:to_s)).update_all(:status => :declined)
  end
  
  def approved?
    self.status == :approved
  end
  
  def decline!
    self.status = :declined
    save!
  end
  
  def rescind!
    self.status = :rescinded
    save!
  end
  
  def editable?
    (self.status.blank? || self.status == :pending) && (!self.trip_ticket.present? || !self.trip_ticket.approved?)
  end
  
  def can_be_auto_approved?
    self.editable? && self.claimant.can_auto_approve_for?(self.trip_ticket.originator)
  end
  
  private
  
  def trip_ticket_is_not_claimed
    if self.trip_ticket && self.trip_ticket.approved?
      errors.add(:base, "You cannot create or modify a claim on a trip ticket once it has an approved claim")
    end
  end

  def trip_ticket_is_not_rescinded
    if self.trip_ticket && self.trip_ticket.rescinded?
      errors.add(:base, "You cannot submit a claim on a trip ticket that has been rescinded")
    end
  end

  def one_claim_per_trip_ticket_per_claimant
    if !self.persisted? && self.trip_ticket.present? && self.claimant.present? && self.trip_ticket.includes_claim_from?(self.claimant)
      errors.add(:base, "You may only create one claim per ticket per provider")
    end
  end
end

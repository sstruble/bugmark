require 'ostruct'

class Contract < ApplicationRecord

  include MatchUtils

  has_paper_trail

  belongs_to :repo            , foreign_key: "stm_repo_uuid" , primary_key: "uuid", optional: true
  belongs_to :issue           , foreign_key: "stm_issue_uuid", primary_key: "uuid", optional: true
  has_one  :prototype         , foreign_key: 'prototype_uuid', primary_key: "uuid", class_name: 'Contract'
  has_many :prototype_children, foreign_key: 'prototype_uuid', primary_key: "uuid", class_name: 'Contract'

  has_many :escrows   , -> {order(:sequence => :asc)}, foreign_key: "contract_uuid", primary_key: "uuid"
  has_many :amendments, -> {order(:sequence => :asc)}, foreign_key: "contract_uuid", primary_key: "uuid"

  has_many :positions, :through => :escrows

  before_validation :default_values

  validates :status, inclusion: {in: %w(open resolved cancelled)}
  validates :maturation, presence: true

  # ----- SCOPES -----
  class << self
    def inc_volsum
      volsum = "sum(escrows.fixed_value)+sum(escrows.unfixed_value) as volsum"
      select("contracts.*", volsum).joins(:escrows).group("id")
    end

    def pending_resolution
      expired.unresolved
    end

    def open
      where(status: 'open')
    end

    def matured
      where("maturation < ?", BugmTime.now)
    end

    def expired
      where("maturation < ?", BugmTime.now)
    end

    def resolved
      where("status = ?", "resolved")
    end

    def unresolved
      where("status != ?", "resolved")
    end

    def select_subset
      select(%i(id uuid type prototype_uuid status stm_status stm_issue_uuid stm_repo_uuid awarded_to))
    end
    alias_method :ss, :select_subset
  end

  # ----- OVERLAP UTILS -----
  class << self
    def overlap(beg, fin)
      where('maturation > ?::timestamp', beg).
        where('maturation < ?::timestamp', fin)
    end
  end

  def overlap_offers
    Offer.by_overlap_maturation(self.maturation)
  end

  # ----- INSTANCE METHODS -----

  def users
    (bid_users + ask_users).uniq
  end

  def attach_type
    self.issue_id ? "bugs" : "repos"
  end

  def attach_obj
    bug || repo
  end

  def bid_tokens
    # bids.reduce(0) {|acc, bid| acc + bid.token_value}
    0
  end

  def ask_tokens
    # asks.reduce(0) {|acc, ask| acc + ask.token_value}
    0
  end

  def distribution_tokens
    bid_tokens + ask_tokens
  end

  def bidder_allocation
    total_bids = bid_tokens
    total_dist = distribution_tokens
    bids.reduce({}) do |acc, bid|
      # acc[bid.id] = ((bid.token_value.to_f / total_bids) * total_dist).to_i
      acc[bid.id] = 1
      acc
    end
  end

  # VALID STATUSES
  # > open      - active
  # > resolved  - assigned
  # > cancelled - cancelled

  def match_assertion
    match_issues.count > 0
  end

  def awardee
    self.awarded_to || begin
      match_assertion ? "fixed" : "unfixed"
    end
  end

  def awardee_user
    self.send awardee.to_sym
  end

  def xtag
    "con"
  end

  def total_value
    (escrows.pluck(:fixed_value).sum + escrows.pluck(:unfixed_value).sum).round(2)
  end

  def value
    opts = {
      fixed: escrows.pluck(:fixed_value).sum    ,
      unfixed: escrows.pluck(:unfixed_value).sum
    }
    OpenStruct.new(opts)
  end

  def maturation_str
    self.maturation.strftime("%b-%d %H:%M:%S")
  end

  def matured?
    self.maturation < BugmTime.now
  end

  def unmatured?
    ! matured?
  end

  def resolved?
    self.status == 'resolved'
  end

  def unresolved?
    ! resolved?
  end

  def dumptree
    dt_hdr
    dump
    escrows.each {|esc| esc.dumptree}
    dt_ftr("contract #{self.id}")
  end
  alias_method :dt, :dumptree

  def dumpstats
    puts "Escrows:   #{escrows.count}"
    puts "Positions: #{positions.count}"
  end

  private

  def default_values
    self.status       ||= 'open'
    self.maturation   ||= BugmTime.now + 1.week
  end
end

# == Schema Information
#
# Table name: contracts
#
#  id             :integer          not null, primary key
#  uuid           :string
#  exid           :string
#  prototype_uuid :integer
#  type           :string
#  status         :string
#  awarded_to     :string
#  maturation     :datetime
#  xfields        :hstore           not null
#  jfields        :jsonb            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  stm_issue_uuid :string
#  stm_repo_uuid  :string
#  stm_title      :string
#  stm_status     :string
#  stm_labels     :string
#  stm_xfields    :hstore           not null
#  stm_jfields    :jsonb            not null
#

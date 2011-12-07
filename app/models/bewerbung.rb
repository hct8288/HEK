class Bewerbung < ActiveRecord::Base
  PERSOENLICHE_ANGABEN = %w[vorname nachname geburtsdatum staatsangehoerigkeit geschlecht familienstand religion foto foto_content_type foto_file_size lebenslauf lebenslauf_content_type lebenslauf_file_size]
  ANSCHRIFT_DER_ELTERN = %w[strasse_und_nummer plz ort land]
  WEITERE_KONTAKTINFORMATIONEN = %w[email mobiltelefon festnetztelefon]
  ANGABEN_ZUM_STUDIUM = %w[hochschule hauptfach anzahl_abgeschlossener_fachsemester studienende angestrebter_abschluss firma firma_plz firma_ort waehrend_der_praxisphasen_im_hek]
  ANGABEN_ZUM_EINZUG = %w[fruehestens wunsch spaetestens geplante_wohndauer]
  VORSTELLUNG = %w[komme_vorbei_am sprechstunge_im_monat vorstellungsgespraech_nicht_moeglich]
  ORGANISATORISCHE_MITTEILUNGEN = %w[organisatorische_mitteilungen]
  INFORMATIONEN = %w[informationen]

  set_table_name 'bewerbungen'

  scope :nicht_abgesagt, where(:bestaetigt => true).where(:zugesagt => [true, nil])
  scope :nicht_bestaetigt, where(:bestaetigt => false)

  has_many :bewertungen, :dependent => :destroy do
    def for benutzer
      @bewertung_for_benutzer ||= inject({}) { |hash, bewertung| hash[bewertung.benutzer] = bewertung.wert; hash }
      @bewertung_for_benutzer[benutzer]
    end
  end

  has_attached_file :temp_foto, {
    :styles => { :medium => "140x140>", :thumb => "100x100#" },
    :url => "/uploads/:hash.:extension",
    :hash_secret => "712be566717dae4560fd7cfcf8214369",
    :hash_data => ":class/:attachment/:style",
    :use_timestamp => false
  }
  validates_attachment_content_type :foto, :content_type => ['image/jpeg', 'image/png', 'image/gif']
  validates_attachment_size :foto, :less_than => 4.megabytes

  has_attached_file :temp_lebenslauf, {
    :url => "/uploads/:hash.:extension",
    :hash_secret => "6a3d3eebbf7356f1420e4359d3r",
    :hash_data => ":class/:attachment/:style",
    :use_timestamp => false
  }
  validates_attachment_content_type :lebenslauf, :content_type => ['application/pdf', 'application/postscript', 'application/rtf', 'application/msword', 'application/vnd.oasis.opendocument.text']
  validates_attachment_size :lebenslauf, :less_than => 6.megabytes

  has_attached_file :foto, {
    :styles => { :medium => "140x140>", :thumb => "48x48#" },
    :url => "/uploads/secure/:hash.:extension",
    :hash_secret => "712be566717dae4560fd7cfcf8214369",
    :hash_data => ":class/:attachment/:id/:style",
    :default_url => '/images/missing_:style.png',
    :use_timestamp => false
  }
  has_attached_file :lebenslauf, {
    :url => "/uploads/secure/:hash.:extension",
    :hash_secret => "6a3d3eebbf7356f1420e4359d3r",
    :hash_data => ":class/:attachment/:id/:style",
    :use_timestamp => false
  }

  validates :vorname,
            :nachname,
            :presence => true
  validates :geburtsdatum, :presence => true, :date => { :before => Proc.new { Time.now - 14.year } }
  validates :strasse_und_nummer, :presence => true
  validates :plz, :presence => true, :numericality => { :greater_than => 0, :less_or_equal_than => 99999, :only_integer => true }
  validates :ort,
            :land,
            :email,
            :presence => true
  validates :firma_plz, :allow_blank => true, :numericality => { :greater_than => 0, :less_or_equal_than => 99999, :only_integer => true }
  validates :anzahl_abgeschlossener_fachsemester, :allow_blank => true, :numericality => { :greater_or_equal_than => 0, :only_integer => true }
  validates :geplante_wohndauer, :allow_blank => true, :numericality => { :greater_than => 0, :only_integer => true }

  validates :studienende, :allow_blank => true, :date => { :after => Proc.new { Time.now } }
  validates :fruehestens, :allow_blank => true, :date => { :before => :wunsch }
# the following behaves strangely. an empty field gives a "not-a-date" error (when the date validator is called first)
# or an "empty" error when you input an invalid date if the presence validator is called first.
  validates :wunsch, :presence => true, :date => { :after => Proc.new { Time.now } }
  validates :spaetestens, :date => { :after => :wunsch }, :allow_blank => true
  validates :komme_vorbei_am, :allow_blank => true, :date => { :after => Proc.new { Time.now } }
# the following fails because the user only has to provide YYYY-MM (not the day)
#  validates :sprechstunde_im_monat, :date => { :after => Proc.new { Time.now } }, :allow_blank => true
  validates :informationen, :presence => true

  def name
    "#{vorname} #{nachname}"
  end

  def alter
    ((Date.today.to_time - geburtsdatum.to_time) / 1.year).round
  end

  def telefon?
    festnetztelefon? or mobiltelefon?
  end

  def abgesagt?
    zugesagt == false
  end

  def update_bewertung
    transaction do
      bewertung = bewertungen.empty? ? 0 : (bewertungen.sum(:wert) / bewertungen.count.to_f)
      update_attribute :bewertung, bewertung
    end
  end

  def recover attribute, path
    if not send(attribute).file? and not path.blank?
      File.open "#{Rails.root}/public/uploads/#{sanitize_filename(path.first)}" do |file|
        send "#{attribute}=", file
      end
    end
  end

private
  # Wundert mich, dass du sowas brauchst.
  def sanitize_filename(filename)
    filename.strip.tap do |name|
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      name.sub! /\A.*(\\|\/)/, ''
      # Finally, replace all non alphanumeric, underscore
      # or periods with underscore
      name.gsub! /[^\w\.\-]/, '_'
    end
  end
end

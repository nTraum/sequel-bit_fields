require 'spec_helper'

class SpecModel < Sequel::Model
  plugin :bit_fields, :status_bits,   [ :started, :finished, { :name => :reviewed, :description => 'This model has been reviewed.' } ]
  plugin :bit_fields, :paranoid_bits, [ :allow_mail ]
end

class AnotherSpecModel < Sequel::Model
  plugin :bit_fields, :some_bits,       [ :fnord ], :scope => :some
  plugin :bit_fields, :some_other_bits, [ :fnord ], :scope => true
end

class SpecRolesModel < Sequel::Model
  plugin :bit_fields, :roles, [:author, :contributor, :reader]
end

class NoBitFieldsSpecModel < Sequel::Model
end

class DirtyModel < Sequel::Model
  plugin :dirty
  plugin :bit_fields, :status_bits, [ :started, :finished, :reviewed ]
end

status_bits_result = [{
  :name        => :started,
  :description => "Description for 'started' not available."
}, {
  :name        => :finished,
  :description => "Description for 'finished' not available."
}, {
  :name        => :reviewed,
  :description => 'This model has been reviewed.'
}]

paranoid_bits_result = [{
  :name        => :allow_mail,
  :description => "Description for 'allow_mail' not available."
}]

describe Sequel::Plugins::BitFields do
  describe :bit_fields_for_models do
    it 'returns all defined bit fields for all models' do
      expect(Sequel::Plugins::BitFields.bit_fields_for_models.keys.sort).to match_array(['AnotherSpecModel', 'SpecModel', 'SpecRolesModel', 'DirtyModel'])
    end
  end

  it "declares the method started= and started?" do
    expect(SpecModel.create).to respond_to(:started=)
    expect(SpecModel.create).to respond_to(:started?)
  end

  it "declares the method finished= and finished?" do
    expect(SpecModel.create).to respond_to(:finished=)
    expect(SpecModel.create).to respond_to(:finished?)
  end

  it "declares the method reviewed= and reviewed?" do
    expect(SpecModel.create).to respond_to(:reviewed=)
    expect(SpecModel.create).to respond_to(:reviewed?)
  end

  it "works with the constructor" do
    expect(SpecModel.new(:started => true).started?).to eq(true)
  end

  describe :bit_fields do
    it "stores the bit fields" do
      expect(SpecModel.bit_fields[:status_bits]).to eq(status_bits_result)
      expect(SpecModel.bit_fields(:status_bits)).to eq(status_bits_result)
      expect(SpecModel.bit_fields[:paranoid_bits]).to eq(paranoid_bits_result)
      expect(SpecModel.bit_fields(:paranoid_bits)).to eq(paranoid_bits_result)
    end

    it "returns all bit_fields of the models" do
      expect(SpecModel.bit_fields).to eq(status_bits: status_bits_result, paranoid_bits: paranoid_bits_result)
    end

    it "returns some_bits of the AnotherSpecModel" do
      expect(AnotherSpecModel.bit_fields).to eq({
        some_bits: [{ name: :some_fnord, description: "Description for 'some_fnord' not available." }],
        some_other_bits: [{ name: :some_other_bits_fnord, description: "Description for 'some_other_bits_fnord' not available." }]
      })
    end

    it "raises if bit_fields is called for a model which doesn't use the plugin" do
      expect { NoBitFieldsSpecModel.bit_fields }.to raise_error(NoMethodError)
    end
  end

  describe :field= do
    context "a freshly created object without any set bit" do
      before do
        @model = SpecModel.create
      end

      it "sets status_bits to 0" do
        expect(@model.status_bits).to eq(0)
      end

      it "sets status_bits to 0 if started is set to false" do
        @model.update(:started => false)
        expect(@model.reload.status_bits).to eq(0)
      end

      it "sets status_bits to 1 if started is set to true" do
        @model.started = true
        expect(@model.status_bits).to eq(1)
      end

      it "evaluates 0 as false" do
        @model.started = 0
        expect(@model.status_bits).to eq(0)
      end

      it "evaluates 1 as true" do
        @model.started = 1
        expect(@model.status_bits).to eq(1)
      end

      it "evaluates '0' as false" do
        @model.started = '0'
        expect(@model.status_bits).to eq(0)
      end

      it "evaluates '1' as true" do
        @model.started = '1'
        expect(@model.status_bits).to eq(1)
      end

      it "evaluates 'false' as false" do
        @model.started = 'false'
        expect(@model.status_bits).to eq(0)
      end

      it "evaluates 'true' as true" do
        @model.started = 'true'
        expect(@model.status_bits).to eq(1)
      end

      it "sets status_bits to 2 if finished is set to true" do
        @model.finished = true
        expect(@model.status_bits).to eq(2)
      end

      it "sets status_bits to 0 if finished is set to false" do
        @model.finished = false
        expect(@model.status_bits).to eq(0)
      end

      it "sets status_bits to 4 if reviewed is set to true" do
        @model.reviewed = true
        expect(@model.status_bits).to eq(4)
      end

      it "sets status_bits to 3 if started and finished is set to true" do
        @model.started = true
        @model.finished = true
        expect(@model.status_bits).to eq(3)
      end

      it "sets status bits to 7 if started and finished and reviewed is set to true" do
        @model.started = true
        @model.finished = true
        @model.reviewed = true
        expect(@model.status_bits).to eq(7)
      end
    end

    context "an instance with finished set to true" do
      before do
        @model = SpecModel.create
        @model.finished = true
      end

      it "sets the status bits to 2" do
        expect(@model.status_bits).to eq(2)
      end

      it "sets the status_bits to 0 if finished was set to false" do
        @model.finished = false
        expect(@model.status_bits).to eq(0)
      end
    end
  end

  describe :field? do
    context "a freshly created object without any bits" do
      before do
        @model = SpecModel.create
      end

      it "returns false for all status_bits" do
        expect(@model.started?).to eq(false)
        expect(@model.finished?).to eq(false)
        expect(@model.reviewed?).to eq(false)
      end
    end

    context "an object with started set to true" do
      before do
        @model = SpecModel.create
        @model.started = true
      end

      it "returns true for started?" do
        expect(@model.started?).to eq(true)
      end

      it "returns false for started? if started was set to false" do
        @model.started = false
        expect(@model.started?).to eq(false)
      end
    end
  end

  # Similar to Sequel#column_changed?
  describe :bit_changed? do
    before do
      @model = DirtyModel.create
    end

    context "model without the dirty plugin" do
      it "throws an error" do
        model = SpecModel.create
        expect {
          model.bit_changed?(:foo)
        }.to raise_error("Dirty plugin was not activated. Add 'plugin :dirty' to your model declaration!")
      end
    end

    context "bit did not change" do
      it "returns false" do
        expect(@model.bit_changed?(:finished)).to eq(false)
      end
    end

    context "bit did change" do
      before do
        @model.finished = !@model.finished?
      end

      context "before save" do
        it "returns true" do
          expect(@model.bit_changed?(:finished)).to eq(true)
        end
      end

      context "after save" do
        before do
          @model.save
        end

        it "returns false" do
          expect(@model.bit_changed?(:finished)).to eq(false)
        end
      end
    end
  end

  describe :field_sql do
    it "returns the sql for truthy comparison of started" do
      expect(SpecModel.started_sql).to eq("`spec_models`.`status_bits` & 1 = 1")
    end

    it "returns the sql for falsy comparison of started" do
      expect(SpecModel.started_sql(false)).to eq("`spec_models`.`status_bits` & 1 != 1")
    end

    it "returns the sql for truthy comparison of finished" do
      expect(SpecModel.finished_sql).to eq("`spec_models`.`status_bits` & 2 = 2")
    end

    it "returns the sql for falsy comparison of finished" do
      expect(SpecModel.finished_sql(false)).to eq("`spec_models`.`status_bits` & 2 != 2")
    end

    it "returns the sql for truthy comparison of reviewed" do
      expect(SpecModel.reviewed_sql).to eq("`spec_models`.`status_bits` & 4 = 4")
    end

    it "returns the sql for falsy comparison of reviewed" do
      expect(SpecModel.reviewed_sql(false)).to eq("`spec_models`.`status_bits` & 4 != 4")
    end

    it "uses the passed table name" do
      expect(SpecModel.reviewed_sql(false, :table => '_spec_models')).to eq("`_spec_models`.`status_bits` & 4 != 4")
    end
  end

  describe :field_dataset do
    it "returns the dataset for truthy comparison of started" do
      expect(SpecModel.started.sql).to eq(
        "SELECT * FROM `spec_models` WHERE (`spec_models`.`status_bits` & 1 = 1)"
      )
    end

    it "returns the dataset for falsy comparison of started" do
      expect(SpecModel.started(false).sql).to eq(
        "SELECT * FROM `spec_models` WHERE (`spec_models`.`status_bits` & 1 != 1)"
      )
    end

    it "returns the dataset for truthy comparison of finished" do
      expect(SpecModel.finished.sql).to eq(
        "SELECT * FROM `spec_models` WHERE (`spec_models`.`status_bits` & 2 = 2)"
      )
    end

    it "returns the dataset for falsy comparison of finished" do
      expect(SpecModel.finished(false).sql).to eq(
        "SELECT * FROM `spec_models` WHERE (`spec_models`.`status_bits` & 2 != 2)"
      )
    end

    it "returns the dataset for truthy comparison of reviewed" do
      expect(SpecModel.reviewed.sql).to eq(
        "SELECT * FROM `spec_models` WHERE (`spec_models`.`status_bits` & 4 = 4)"
      )
    end

    it "returns the dataset for falsy comparison of reviewed" do
      expect(SpecModel.reviewed(false).sql).to eq(
        "SELECT * FROM `spec_models` WHERE (`spec_models`.`status_bits` & 4 != 4)"
      )
    end

    it "allows chaining of datasets" do
      expect(SpecModel.started.reviewed(false).sql).to eq(
        "SELECT * FROM `spec_models` WHERE ((`spec_models`.`status_bits` & 1 = 1) AND (`spec_models`.`status_bits` & 4 != 4))"
      )
    end
  end

  describe :status_bits do
    context "an object with finished set to true" do
      before do
        @model = SpecModel.create
        @model.finished = true
      end

      it "returns false for finished? if status_bits was set to 0" do
        @model.status_bits = 0
        expect(@model.finished?).to eq(false)
      end
    end
  end

  describe :bit_field_column= do
    context "an object with roles set to :author" do
      before do
        @model = SpecRolesModel.create
        @model.roles = :author
      end

      it "returns true for author?" do
        expect(@model.author?).to eq(true)
      end

      it "returns false for reader? and contributor?" do
        expect(@model.reader?).to eq(false)
        expect(@model.contributor?).to eq(false)
      end
    end

    context "an object with roles set to [:reader,:contributor]" do
      before do
        @model = SpecRolesModel.create
        @model.roles = [:reader,:contributor]
      end

      it "returns true for reader? and contributor? and returns false for author?" do
        expect(@model.reader?).to eq(true)
        expect(@model.contributor?).to eq(true)
        expect(@model.author?).to eq(false)
      end

      it "returns false for reader? and contributor? if roles set to :author" do
        @model.roles = :author
        expect(@model.reader?).to eq(false)
        expect(@model.contributor?).to eq(false)
      end

      context "an object with roles set to 6" do
        before do
          @model = SpecRolesModel.create
          @model.roles = 6
        end

        it "returns true for reader? and contributor? and returns false for author?" do
          expect(@model.reader?).to eq(true)
          expect(@model.contributor?).to eq(true)
          expect(@model.author?).to eq(false)
        end

        it "returns false for author? reader? and contributor? if roles set to 0" do
          @model.roles = 0
          expect(@model.reader?).to eq(false)
          expect(@model.contributor?).to eq(false)
          expect(@model.author?).to eq(false)
        end

        it "returns true for author? and false for reader? and contributor? if roles set to 1" do
          @model.roles = 1
          expect(@model.reader?).to eq(false)
          expect(@model.contributor?).to eq(false)
          expect(@model.author?).to eq(true)
        end
      end

      context "an object with roles set to []" do
        before do
          @model = SpecRolesModel.create
          @model.roles = []
        end

        it "returns false for author? reader? and contributor?" do
          expect(@model.reader?).to eq(false)
          expect(@model.contributor?).to eq(false)
          expect(@model.author?).to eq(false)
        end

        it "returns true for author? if roles set to [:author]" do
          @model.roles = [:author]
          expect(@model.author?).to eq(true)
        end
      end
    end
  end

  describe :bit_field_values_for do
    context "an object with finished set to true" do
      before do
        @model = SpecModel.create
        @model.finished = true
      end

      it "returns a representing hash of values" do
        values = @model.bit_field_values_for(:status_bits)
        expect(values).to eq({ :finished => true, :started => false, :reviewed => false })
      end

      it "returns a hash with value equal to true value" do
        values = @model.bit_field_values_for(:status_bits, true)
        expect(values).to eq({:finished => true})
      end

      it "returns a hash with value equal to false value" do
        values = @model.bit_field_values_for(:status_bits, false)
        expect(values).to eq({:started => false, :reviewed => false})
      end
    end
  end

  describe :bit_field_indexes_for do
    it "returns a hash with the name of the bit fields and its representing indexes" do
      hash = SpecModel.bit_field_indexes_for(:status_bits)
      expect(hash).to eq({ :started => 1, :finished => 2, :reviewed => 4 })
    end
  end

  describe :scope do
    before do
      @model = AnotherSpecModel.create
    end

    it "adds the scope to the setter" do
      expect{ @model.some_fnord = true }.to_not raise_error
      expect{ @model.some_other_bits_fnord = true }.to_not raise_error
    end

    it "adds the scope to the getter" do
      expect{ @model.some_fnord? }.to_not raise_error
      expect{ @model.some_other_bits_fnord? }.to_not raise_error
    end
  end
end

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#flash_css_class' do
    context 'when flash type is alert or error' do
      it 'returns brutalist-error CSS class for alert symbol' do
        expect(helper.flash_css_class(:alert)).to eq('brutalist-error')
      end

      it 'returns brutalist-error CSS class for alert string' do
        expect(helper.flash_css_class('alert')).to eq('brutalist-error')
      end

      it 'returns brutalist-error CSS class for error symbol' do
        expect(helper.flash_css_class(:error)).to eq('brutalist-error')
      end

      it 'returns brutalist-error CSS class for error string' do
        expect(helper.flash_css_class('error')).to eq('brutalist-error')
      end
    end

    context 'when flash type is notice or success' do
      it 'returns brutalist-success CSS class for notice symbol' do
        expect(helper.flash_css_class(:notice)).to eq('brutalist-success')
      end

      it 'returns brutalist-success CSS class for notice string' do
        expect(helper.flash_css_class('notice')).to eq('brutalist-success')
      end

      it 'returns brutalist-success CSS class for success symbol' do
        expect(helper.flash_css_class(:success)).to eq('brutalist-success')
      end

      it 'returns brutalist-success CSS class for success string' do
        expect(helper.flash_css_class('success')).to eq('brutalist-success')
      end
    end

    context 'when flash type is warning' do
      it 'returns brutalist-warning CSS class for warning symbol' do
        expect(helper.flash_css_class(:warning)).to eq('brutalist-warning')
      end

      it 'returns brutalist-warning CSS class for warning string' do
        expect(helper.flash_css_class('warning')).to eq('brutalist-warning')
      end
    end

    context 'when flash type is unknown' do
      it 'returns brutalist-info CSS class for unknown symbol' do
        expect(helper.flash_css_class(:unknown)).to eq('brutalist-info')
      end

      it 'returns brutalist-info CSS class for unknown string' do
        expect(helper.flash_css_class('unknown')).to eq('brutalist-info')
      end

      it 'returns brutalist-info CSS class for nil' do
        expect(helper.flash_css_class(nil)).to eq('brutalist-info')
      end
    end
  end
end

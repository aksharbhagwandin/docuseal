<template>
  <div dir="auto">
    <div class="flex justify-between items-center w-full mb-2">
      <label
        class="label text-2xl"
      >{{ showFieldNames && field.name ? field.name : t('initials') }}</label>
      <div class="space-x-2 flex">
        <span
          v-if="isDrawInitials"
          class="tooltip"
          :data-tip="t('type_initials')"
        >
          <a
            id="type_text_button"
            href="#"
            class="btn btn-outline font-medium btn-sm"
            @click.prevent="toggleTextInput"
          >
            <IconTextSize :width="16" />
            <span class="hidden sm:inline">
              {{ t('type') }}
            </span>
          </a>
        </span>
        <span
          v-else
          class="tooltip ml-2"
          :data-tip="t('draw_initials')"
        >
          <a
            id="type_text_button"
            href="#"
            class="btn btn-outline font-medium btn-sm"
            @click.prevent="toggleTextInput"
          >
            <IconSignature :width="16" />
            <span class="hidden sm:inline">
              {{ t('draw') }}
            </span>
          </a>
        </span>
        <a
          v-if="modelValue || computedPreviousValue"
          href="#"
          class="btn font-medium btn-outline btn-sm"
          @click.prevent="remove"
        >
          <IconReload :width="16" />
          {{ t('clear') }}
        </a>
        <a
          v-else
          href="#"
          class="btn font-medium btn-outline btn-sm"
          @click.prevent="clear"
        >
          <IconReload :width="16" />
          {{ t('clear') }}
        </a>
        <a
          title="Minimize"
          href="#"
          class="py-1.5 inline md:hidden"
          @click.prevent="$emit('minimize')"
        >
          <IconArrowsDiagonalMinimize2
            :width="20"
            :height="20"
          />
        </a>
      </div>
    </div>
    <AppearsOn :field="field" />
    <input
      :value="modelValue || computedPreviousValue"
      type="hidden"
      :name="`values[${field.uuid}]`"
    >
    <img
      v-if="modelValue || computedPreviousValue"
      :src="attachmentsIndex[modelValue || computedPreviousValue].url"
      class="mx-auto bg-white border border-base-300 rounded max-h-72"
    >
    <canvas
      v-show="!modelValue && !computedPreviousValue"
      ref="canvas"
      class="bg-white border border-base-300 rounded-2xl w-full"
    />
    <input
      v-if="!isDrawInitials && !modelValue && !computedPreviousValue"
      id="initials_text_input"
      ref="textInput"
      class="base-input !text-2xl w-full mt-6 text-center"
      :required="field.required && !isInitialsStarted"
      :placeholder="`${t('type_initial_here')}...`"
      type="text"
      @focus="$emit('focus')"
      @input="updateWrittenInitials"
    >
  </div>
</template>

<script>
import { cropCanvasAndExportToPNG } from './crop_canvas'
import { IconReload, IconTextSize, IconSignature, IconArrowsDiagonalMinimize2 } from '@tabler/icons-vue'
import SignaturePad from 'signature_pad'
import AppearsOn from './appears_on'

const scale = 3

export default {
  name: 'InitialsStep',
  components: {
    AppearsOn,
    IconReload,
    IconTextSize,
    IconSignature,
    IconArrowsDiagonalMinimize2
  },
  inject: ['baseUrl', 't'],
  props: {
    field: {
      type: Object,
      required: true
    },
    submitterSlug: {
      type: String,
      required: true
    },
    showFieldNames: {
      type: Boolean,
      required: false,
      default: true
    },
    isDirectUpload: {
      type: Boolean,
      required: true,
      default: false
    },
    attachmentsIndex: {
      type: Object,
      required: false,
      default: () => ({})
    },
    previousValue: {
      type: String,
      required: false,
      default: ''
    },
    modelValue: {
      type: String,
      required: false,
      default: ''
    }
  },
  emits: ['attached', 'update:model-value', 'start', 'minimize', 'focus'],
  data () {
    return {
      isInitialsStarted: !!this.previousValue,
      isUsePreviousValue: true,
      isDrawInitials: false
    }
  },
  computed: {
    computedPreviousValue () {
      if (this.isUsePreviousValue) {
        return this.previousValue
      } else {
        return null
      }
    }
  },
  async mounted () {
    this.$nextTick(() => {
      if (this.$refs.canvas) {
        this.$refs.canvas.width = this.$refs.canvas.parentNode.clientWidth * scale
        this.$refs.canvas.height = (this.$refs.canvas.parentNode.clientWidth / 3) * scale

        this.$refs.canvas.getContext('2d').scale(scale, scale)
      }

      this.$refs.textInput?.focus()
    })

    if (this.isDirectUpload) {
      import('@rails/activestorage')
    }

    if (this.$refs.canvas) {
      this.pad = new SignaturePad(this.$refs.canvas)

      this.pad.addEventListener('beginStroke', () => {
        this.isInitialsStarted = true

        this.$emit('start')
      })

      this.intersectionObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.$refs.canvas.width = this.$refs.canvas.parentNode.clientWidth * scale
            this.$refs.canvas.height = (this.$refs.canvas.parentNode.clientWidth / 3) * scale

            this.$refs.canvas.getContext('2d').scale(scale, scale)

            this.intersectionObserver?.disconnect()
          }
        })
      })

      this.intersectionObserver.observe(this.$refs.canvas)
    }
  },
  beforeUnmount () {
    this.intersectionObserver?.disconnect()
  },
  methods: {
    remove () {
      this.$emit('update:model-value', '')

      this.isUsePreviousValue = false
      this.isInitialsStarted = false
    },
    clear () {
      this.pad.clear()

      this.isInitialsStarted = false

      if (this.$refs.textInput) {
        this.$refs.textInput.value = ''
      }
    },
    updateWrittenInitials (e) {
      this.isInitialsStarted = true

      const canvas = this.$refs.canvas
      const context = canvas.getContext('2d')

      const fontFamily = 'Arial'
      const fontSize = '44px'
      const fontStyle = 'italic'
      const fontWeight = ''

      context.font = fontStyle + ' ' + fontWeight + ' ' + fontSize + ' ' + fontFamily
      context.textAlign = 'center'

      context.clearRect(0, 0, canvas.width / scale, canvas.height / scale)
      context.fillText(e.target.value, canvas.width / 2 / scale, canvas.height / 2 / scale + 11)
    },
    toggleTextInput () {
      this.remove()
      this.clear()
      this.isDrawInitials = !this.isDrawInitials

      if (!this.isDrawInitials) {
        this.$nextTick(() => {
          this.$refs.textInput.focus()

          this.$emit('start')
        })
      }
    },
    async submit () {
      if (this.modelValue || this.computedPreviousValue) {
        if (this.computedPreviousValue) {
          this.$emit('update:model-value', this.computedPreviousValue)
        }

        return Promise.resolve({})
      }

      return new Promise((resolve) => {
        cropCanvasAndExportToPNG(this.$refs.canvas).then(async (blob) => {
          const file = new File([blob], 'initials.png', { type: 'image/png' })

          if (this.isDirectUpload) {
            const { DirectUpload } = await import('@rails/activestorage')

            new DirectUpload(
              file,
              '/direct_uploads'
            ).create((_error, data) => {
              fetch(this.baseUrl + '/api/attachments', {
                method: 'POST',
                body: JSON.stringify({
                  submitter_slug: this.submitterSlug,
                  blob_signed_id: data.signed_id,
                  name: 'attachments'
                }),
                headers: { 'Content-Type': 'application/json' }
              }).then((resp) => resp.json()).then((attachment) => {
                this.$emit('update:model-value', attachment.uuid)
                this.$emit('attached', attachment)

                return resolve(attachment)
              })
            })
          } else {
            const formData = new FormData()

            formData.append('file', file)
            formData.append('submitter_slug', this.submitterSlug)
            formData.append('name', 'attachments')

            return fetch(this.baseUrl + '/api/attachments', {
              method: 'POST',
              body: formData
            }).then((resp) => resp.json()).then((attachment) => {
              this.$emit('attached', attachment)
              this.$emit('update:model-value', attachment.uuid)

              return resolve(attachment)
            })
          }
        })
      })
    }
  }
}
</script>

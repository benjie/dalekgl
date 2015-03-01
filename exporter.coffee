{App, SCREEN_RATIO, ANIMATION_DURATION, ANIMATION_INTERVAL} = require './script'
VIDEO_WIDTH=1920
VIDEO_HEIGHT=1080

class Exporter extends App
  decalRotationMatrix: (inner) -> "decal_rotation_matrix(#{if inner then 1 else 0})"
  beginInitShaders: ->
    @output.push "\n\nstatic void init_shaders(CUBE_STATE_T *state)\n{"

  endInitShaders: ->
    @output.push "}"

  beginInitShapes: ->
    @output.push "\n\nstatic void init_shapes(CUBE_STATE_T *state)\n{"

  endInitShapes: ->
    @output.push "}"

  initCanvas: ->
  initGLContext: ->
    @GL =
      clearColor: ->

  createVertexAndFaceBuffers: (name, object, vertexData, facesData) ->
    @buffers.push {name, object, vertexData, facesData}
    object.name = name
    object.triangleVertexData = vertexData
    object.triangleFacesData = facesData
    object.triangleVertex = Math.random()
    object.triangleFaces = Math.random()
    block = (data, indent, size) ->
      indentString = new Array(indent + 1).join(" ")
      dataString = []
      for number, i in data
        if (i % size) == 0
          dataString.push "\n#{indentString}"
        dataString.push "#{number}, "
      dataString = dataString.join("").replace(/[\n, ]*$/, "")
      return dataString

    @output.push """

      //////////////////////
      // #{name} vertex data
      //////////////////////
        check();
        static const GLfloat #{name}VertexData[] = {#{block(vertexData, 4, 6)}
        };
        glGenBuffers(1, &state->#{name}VertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, state->#{name}VertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(#{name}VertexData), #{name}VertexData, GL_STATIC_DRAW);
        check();

      //////////////////////
      // #{name} faces data
      //////////////////////
        static unsigned short #{name}FacesData[] = {#{block(facesData, 4, 6)}
        };
        glGenBuffers(1, &state->#{name}FacesBuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, state->#{name}FacesBuffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(#{name}FacesData), #{name}FacesData, GL_STATIC_DRAW);
        check();

      """

  initTexture: ->
    @output.push """
      static void init_texture(CUBE_STATE_T *state)
      {
        check();
        load_tex_images(state);
        check();
        glActiveTexture(GL_TEXTURE0);
        glGenTextures(1, &state->texture);
        check();
        //glPixelStorei(UNPACK_FLIP_Y_WEBGL, true);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, state->texture);
        check();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        check();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        check();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        check();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        check();

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, IMAGE_SIZE_WIDTH, IMAGE_SIZE_HEIGHT, 0,
                GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        check();

        /* Create EGL Image */
        eglImage = eglCreateImageKHR(
                     state->display,
                     state->context,
                     EGL_GL_TEXTURE_2D_KHR,
                     (EGLClientBuffer)state->texture,
                     0);

        if (eglImage == EGL_NO_IMAGE_KHR)
        {
           printf("eglCreateImageKHR failed.\\n");
           exit(1);
        }

        // Start rendering
        pthread_create(&thread1, NULL, video_decode_test, eglImage);




        glBindTexture(GL_TEXTURE_2D, 0);
        check();
      }
      """
  initElements: ->
  createNamedShader: (name, attributes, uniforms) ->
    program = {}
    @shaders.push {name, attributes, uniforms}
    enableVertexArrays = (enable = true) ->
      tmp = []
      for varName in attributes
        tmp.push "  gl#{if enable then "Enable" else "Disable"}VertexAttribArray(state->#{name}_attr_#{varName});\n  check();"
      return tmp.join("\n")

    @shaderMethods.push """

      static void #{name}ShaderEnable(CUBE_STATE_T *state)
      {
        glUseProgram(state->#{name}Program);
        check();
      #{enableVertexArrays()}
      }

      static void #{name}ShaderDisable(CUBE_STATE_T *state)
      {
      #{enableVertexArrays(false)}
      }

      """
    output = @output

    output.push "  const GLchar *#{name}VertexShaderSource ="
    source = this["#{name}VertexShaderSource"]
    for line in source.split(/\n/)
      output.push "    \"#{line}\\n\""
    output[output.length-1] += ";"

    output.push "  const GLchar *#{name}FragmentShaderSource ="
    source = this["#{name}FragmentShaderSource"]
    for line in source.split(/\n/)
      output.push "    \"#{line}\""
    output[output.length-1] += ";"

    output.push """

      //////////////////////
      // #{name} shader
      //////////////////////

        check();
        state->#{name}VertexShader = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(state->#{name}VertexShader, 1, &#{name}VertexShaderSource, 0);
        check();
        glCompileShader(state->#{name}VertexShader);
        check();

        if (state->verbose) {
          showlog(state->#{name}VertexShader);
        }

        check();
        state->#{name}FragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(state->#{name}FragmentShader, 1, &#{name}FragmentShaderSource, 0);
        check();
        glCompileShader(state->#{name}FragmentShader);
        check();

        if (state->verbose) {
          showlog(state->#{name}FragmentShader);
        }

        state->#{name}Program = glCreateProgram();
        glAttachShader(state->#{name}Program, state->#{name}VertexShader);
        check();
        glAttachShader(state->#{name}Program, state->#{name}FragmentShader);
        check();
        glLinkProgram(state->#{name}Program);
        check();

        if (state->verbose) {
          showprogramlog(state->#{name}Program);
        }
      """

    for attribute in attributes
      output.push "  state->#{name}_attr_#{attribute} = glGetAttribLocation(state->#{name}Program, \"#{attribute}\");\n  check();"
      program["_#{attribute}"] = attribute
    for uniform in uniforms
      output.push "  state->#{name}_unif_#{uniform} = glGetUniformLocation(state->#{name}Program, \"#{uniform}\");\n  check();"
      program["_#{uniform}"] = uniform

    program.use = (fn) =>
      oldGL = @GL
      @GL =
        uniform1f: (prop, val) => @output.push "  glUniform1f(state->#{name}_unif_#{prop}, #{val});check();"
        uniform1i: (prop, val) => @output.push "  glUniform1i(state->#{name}_unif_#{prop}, #{val});check();"
        uniformMatrix2fv: (prop, transpose, val) =>
          if typeof val is 'string'
            # do nothing - likely a function call
          else
            # interpret as array
            val = "(GLfloat[]){#{Array::slice.call(val).join(",")}}"
          @output.push "  glUniformMatrix2fv(state->#{name}_unif_#{prop}, 4, GL_FALSE, #{val});check();"
        bindBuffer: (type, target) =>
          if type is @GL.ARRAY_BUFFER
            typeName = "GL_ARRAY_BUFFER"
            for k, v of @ when v?.triangleVertex is target
              targetName = "state->#{v.name}VertexBuffer"
          else if type is @GL.ELEMENT_ARRAY_BUFFER
            typeName = "GL_ELEMENT_ARRAY_BUFFER"
            for k, v of @ when v?.triangleFaces is target
              targetName = "state->#{v.name}FacesBuffer"
          else
            throw new Error "Unknown type"
          throw new Error "target '#{target}' not found for #{typeName}" unless targetName
          @output.push "  glBindBuffer(#{typeName}, #{targetName});check();"
        vertexAttribPointer: (attribute, sthg, type, flse, step, offset) =>
          @output.push "  glVertexAttribPointer(state->#{name}_attr_#{attribute}, #{sthg}, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * #{step/4}, (char *)NULL + sizeof(GLfloat) * #{offset/4});check();"
        drawElements: (method, count, type, sthg) =>
          @output.push "  glDrawElements(GL_TRIANGLES, #{count}, GL_UNSIGNED_SHORT, #{sthg});check();"

      @output.push """


        //////////////////////
        // #{name}
        //////////////////////
        """
      @GL[k] ?= v for k, v of oldGL

      @output.push "  #{name}ShaderEnable(state);"
      fn()
      @output.push "  #{name}ShaderDisable(state);"
      @output.push ""

      @GL = oldGL
      return

    return program

  export: ->
    @output = []
    @shaderMethods = []
    @buffers = []
    @shaders = []

    @init()

    shaderDefinitions = ({name, attributes, uniforms}) ->
      tmp = []
      for attribute in attributes
        tmp.push "  GLuint #{name}_attr_#{attribute};"
      for uniform in uniforms
        tmp.push "  GLuint #{name}_unif_#{uniform};"
      tmp.push "  GLuint #{name}Program;"
      tmp.push "  GLuint #{name}VertexShader;"
      tmp.push "  GLuint #{name}FragmentShader;"
      return tmp.join("\n")

    @output.unshift """
      #include <stdio.h>
      #include <fcntl.h>
      #include <stdlib.h>
      #include <string.h>
      #include <math.h>
      #include <assert.h>
      #include <unistd.h>
      #include <sys/time.h>

      #include "bcm_host.h"

      #include "GLES2/gl2.h"
      #include "EGL/egl.h"
      #include "EGL/eglext.h"
      #include "dalek.h"

      #define PATH "./"
      #define IMAGE_SIZE 128
      #define IMAGE_SIZE_WIDTH #{VIDEO_WIDTH}
      #define IMAGE_SIZE_HEIGHT #{VIDEO_HEIGHT}
      #define max(a,b) (a > b ? a : b)
      #define PI M_PI

      typedef struct
      {
        uint32_t screen_width;
        uint32_t screen_height;
      // OpenGL|ES objects
        EGLDisplay display;
        EGLSurface surface;
        EGLContext context;

        GLuint verbose;
        GLuint vshader;
        GLuint fshader;
        GLuint mshader;
        GLuint program;
        GLuint program2;
        GLuint outputTextureFramebuffer;
        GLuint outputTexture;

        GLuint texture;

      #{(shaderDefinitions(shader) for shader in @shaders).join("\n\n")}

      #{(
      for {name} in @buffers
        "  GLuint #{name}VertexBuffer;\n" +
        "  GLuint #{name}FacesBuffer;\n"
      ).join("\n")}

      // julia attribs
        GLuint unif_color, attr_vertex, unif_scale, unif_offset, unif_tex, unif_centre;
      // mandelbrot attribs
        GLuint attr_vertex2, unif_scale2, unif_offset2, unif_centre2;

        char * tex_buf1;

      } CUBE_STATE_T;

      static CUBE_STATE_T _state, *state=&_state;
      static void* eglImage = 0;
      static pthread_t thread1;

      #define check() assert(glGetError() == 0)

      static void showlog(GLint shader)
      {
         // Prints the compile log for a shader
         char log[1024];
         glGetShaderInfoLog(shader,sizeof log,NULL,log);
         printf("%d:shader:\\n%s\\n", shader, log);
      }

      static void showprogramlog(GLint shader)
      {
         // Prints the information log for a program object
         char log[1024];
         glGetProgramInfoLog(shader,sizeof log,NULL,log);
         printf("%d:program:\\n%s\\n", shader, log);
      }

      static void load_tex_images(CUBE_STATE_T *state)
      {
        FILE *tex_file1 = NULL;
        int bytes_read, image_sz = IMAGE_SIZE*IMAGE_SIZE*3;

        state->tex_buf1 = malloc(image_sz);

        tex_file1 = fopen(PATH "Lucca_128_128.raw", "rb");
        if (tex_file1 && state->tex_buf1)
        {
           bytes_read=fread(state->tex_buf1, 1, image_sz, tex_file1);
           assert(bytes_read == image_sz);  // some problem with file?
           fclose(tex_file1);
        }

      }
      """

    @output.push """


      static void init_ogl(CUBE_STATE_T *state)
      {
        int32_t success = 0;
        EGLBoolean result;
        EGLint num_config;

        static EGL_DISPMANX_WINDOW_T nativewindow;

        DISPMANX_ELEMENT_HANDLE_T dispman_element;
        DISPMANX_DISPLAY_HANDLE_T dispman_display;
        DISPMANX_UPDATE_HANDLE_T dispman_update;
        VC_RECT_T dst_rect;
        VC_RECT_T src_rect;

        static const EGLint attribute_list[] =
        {
           EGL_RED_SIZE, 8,
           EGL_GREEN_SIZE, 8,
           EGL_BLUE_SIZE, 8,
           EGL_ALPHA_SIZE, 8,
           EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
           EGL_NONE
        };

        static const EGLint context_attributes[] =
        {
           EGL_CONTEXT_CLIENT_VERSION, 2,
           EGL_NONE
        };
        EGLConfig config;

        // get an EGL display connection
        state->display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        assert(state->display!=EGL_NO_DISPLAY);
        check();

        // initialize the EGL display connection
        result = eglInitialize(state->display, NULL, NULL);
        assert(EGL_FALSE != result);
        check();

        // get an appropriate EGL frame buffer configuration
        result = eglChooseConfig(state->display, attribute_list, &config, 1, &num_config);
        assert(EGL_FALSE != result);
        check();

        // get an appropriate EGL frame buffer configuration
        result = eglBindAPI(EGL_OPENGL_ES_API);
        assert(EGL_FALSE != result);
        check();

        // create an EGL rendering context
        state->context = eglCreateContext(state->display, config, EGL_NO_CONTEXT, context_attributes);
        assert(state->context!=EGL_NO_CONTEXT);
        check();

        // create an EGL window surface
        success = graphics_get_display_size(0 /* LCD */, &state->screen_width, &state->screen_height);
        assert( success >= 0 );

        dst_rect.x = 0;
        dst_rect.y = 0;
        dst_rect.width = state->screen_width;
        dst_rect.height = state->screen_height;

        src_rect.x = 0;
        src_rect.y = 0;
        src_rect.width = state->screen_width << 16;
        src_rect.height = state->screen_height << 16;

        dispman_display = vc_dispmanx_display_open( 0 /* LCD */);
        dispman_update = vc_dispmanx_update_start( 0 );

        dispman_element = vc_dispmanx_element_add ( dispman_update, dispman_display,
           0/*layer*/, &dst_rect, 0/*src*/,
           &src_rect, DISPMANX_PROTECTION_NONE, 0 /*alpha*/, 0/*clamp*/, 0/*transform*/);

        nativewindow.element = dispman_element;
        nativewindow.width = state->screen_width;
        nativewindow.height = state->screen_height;
        vc_dispmanx_update_submit_sync( dispman_update );

        check();

        state->surface = eglCreateWindowSurface( state->display, config, &nativewindow, NULL );
        assert(state->surface != EGL_NO_SURFACE);
        check();

        // connect the context to the surface
        result = eglMakeCurrent(state->display, state->surface, state->surface, state->context);
        assert(EGL_FALSE != result);
        check();

        // Set background color and clear buffers
        glClearColor(0.15f, 0.25f, 0.35f, 1.0f);
        check();
        glClear( GL_COLOR_BUFFER_BIT );

        check();
      }
      static void init_summink(CUBE_STATE_T *state)
      {
        check();

        // Prepare a texture image
        glGenTextures(1, &state->outputTexture);
        check();
        glBindTexture(GL_TEXTURE_2D,state->outputTexture);
        check();
        // glActiveTexture(0)
        glTexImage2D(GL_TEXTURE_2D,0,GL_RGB,state->screen_width,state->screen_height,0,GL_RGB,GL_UNSIGNED_SHORT_5_6_5,0);
        check();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        check();
        // Prepare a framebuffer for rendering
        glGenFramebuffers(1,&state->outputTextureFramebuffer);
        check();
        glBindFramebuffer(GL_FRAMEBUFFER,state->outputTextureFramebuffer);
        check();
        glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,state->outputTexture,0);
        check();
        glBindFramebuffer(GL_FRAMEBUFFER,0);
        check();
        // Prepare viewport
        glViewport ( 0, 0, state->screen_width, state->screen_height );
        check();
      }
      """
    @output = @output.concat(@shaderMethods)
    @output.push """

      GLfloat rotation_matrix[4];
      static GLfloat* decal_rotation_matrix(int inner)
      {
        struct timeval tv;
        gettimeofday(&tv, NULL);

        unsigned int interval_duration = #{ANIMATION_DURATION};
        unsigned int interval_count = #{ANIMATION_INTERVAL};
        interval_count = max(ceil(interval_count / 2.) * 2, 2);

        unsigned long current_time = (long long)((tv.tv_sec) * 1000. + (tv.tv_usec) / 1000.) % (interval_duration * interval_count);

        //unsigned long long interval = floor(current_time / (GLfloat)interval_duration);
        //unsigned int step = interval % interval_count;

        int interval = floor(current_time / (GLfloat)interval_duration);
        int step = interval % interval_count;
        GLfloat rotation_amount, position;
        if (step == 0) {
          position = (current_time % interval_duration) / (interval_duration - 1.);
          rotation_amount = sin(position * PI / 2);
        } else if (step == interval_count / 2) {
          position = (current_time % interval_duration) / (interval_duration - 1.);
          rotation_amount = sin((1 - position) * PI / 2);
        } else if (step < interval_count / 2) {
          rotation_amount = 1;
        } else {
          rotation_amount = 0;
        }
        GLfloat angle = rotation_amount * (inner == 1 ? PI/4 : -PI/4);



        rotation_matrix[0] = cos(angle);
        rotation_matrix[1] = -sin(angle);
        rotation_matrix[2] = sin(angle);
        rotation_matrix[3] = cos(angle);
        return rotation_matrix;
      }

      static void draw_triangles(CUBE_STATE_T *state)
      {
        // Now render to the main frame buffer
        glBindFramebuffer(GL_FRAMEBUFFER,0);
        glActiveTexture(GL_TEXTURE0);
      """
    @canvas =
      width: VIDEO_WIDTH
      height: VIDEO_HEIGHT
    @video =
      loaded: true
      paused: false
    @GL =
      ARRAY_BUFFER: 'ARRAY_BUFFER'
      ELEMENT_ARRAY_BUFFER: 'ELEMENT_ARRAY_BUFFER'
      viewport: (x, y, w, h) => @output.push "  glViewport(0, 0, state->screen_width, state->screen_height);check();"
      clear: (modes) => @output.push "  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);check();"
      bindTexture: (type, texture) => @output.push "  glBindTexture(GL_TEXTURE_2D, state->texture);check();"
      texImage2D: => ""
      flush: => @output.push "  glFlush();check();"
      finish: => @output.push "  glFinish();check();"

    @draw()

    @output.push """
        glBindTexture(GL_TEXTURE_2D, 0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        eglSwapBuffers(state->display, state->surface);
        check();
      }

      int main ()
      {
        bcm_host_init();

        // Clear application state
        memset(state, 0, sizeof(*state));
        state->verbose = 1;

        printf("Initialising...\\n");
        // Start OGLES
        init_ogl(state);
        init_shaders(state);
        init_shapes(state);
        init_texture(state);
        init_summink(state);
        printf("Initialised.\\n");

        //draw_mandelbrot_to_texture(state);
        while (1)
        {
          draw_triangles(state);
        }
        return 0;
      }
      """
    return @output.join("\n")


exporter = new Exporter
console.log exporter.export()
